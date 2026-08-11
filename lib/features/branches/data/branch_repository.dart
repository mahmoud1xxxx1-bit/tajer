import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/branch.dart';
import '../presentation/branch_context.dart';
import '../../../core/services/entitlement_integration.dart';
import '../../../core/services/entitlement_evaluator.dart';

class BranchRepository {
  final FirebaseFirestore _firestore;
  final String merchantId;

  BranchRepository(this._firestore, this.merchantId);

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('merchants').doc(merchantId).collection('branches');

  String newBranchId() => _ref.doc().id;

  Stream<List<Branch>> watchBranches({List<String>? allowedBranchIds}) {
    if (allowedBranchIds != null && allowedBranchIds.isEmpty) {
      return Stream.value(const <Branch>[]);
    }
    final query = allowedBranchIds == null
        ? _ref.orderBy('createdAt')
        : _ref.where(FieldPath.documentId, whereIn: allowedBranchIds);
    return query.snapshots().map((snapshot) {
      final branches = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['merchantId'] = data['merchantId']?.toString() ?? merchantId;
        return Branch.fromJson(data);
      }).toList();

      branches.sort((a, b) {
        if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
      return branches;
    });
  }

  Future<Branch> ensureMainBranch({required String fallbackName}) async {
    final docRef = _ref.doc(BranchIds.main);
    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = Map<String, dynamic>.from(snapshot.data()!);
      data['id'] = snapshot.id;
      data['merchantId'] = merchantId;
      return Branch.fromJson(data);
    }

    final branch = Branch.main(
      merchantId: merchantId,
      name: fallbackName.trim().isEmpty ? 'Main Branch' : fallbackName.trim(),
    );
    await docRef.set(branch.toJson());
    return branch;
  }

  Future<void> addBranch(Branch branch) async {
    if (branch.merchantId != merchantId) {
      throw StateError('Branch merchant mismatch');
    }

    // Integrate Entitlement Evaluator
    final userDoc = await _firestore.collection('users').doc(merchantId).get();
    final plan = userDoc.data()?['plan'] as String?;
    final tier = EntitlementIntegration.resolveEffectiveTier(plan);

    final snapshot = await _ref.orderBy('createdAt').get();
    final branchesCount = snapshot.docs.length;
    final branchPosition = branchesCount + 1; // logical position

    if (!EntitlementEvaluator.canAccessBranch(tier, branchPosition)) {
      throw Exception("You have reached the maximum available branches for your current plan.");
    }

    await _guardDuplicateName(branch.name);
    await _ref.doc(branch.id).set(branch.toJson());
  }

  Future<void> updateBranch(Branch branch) async {
    if (branch.merchantId != merchantId) {
      throw StateError('Branch merchant mismatch');
    }
    await _guardDuplicateName(branch.name, exceptId: branch.id);
    await _ref.doc(branch.id).update(branch.toJson());
  }

  Future<void> setBranchActive(String branchId, bool isActive) async {
    if (branchId == BranchIds.main && !isActive) {
      throw StateError('The main branch cannot be disabled');
    }
    await _ref.doc(branchId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _guardDuplicateName(String name, {String? exceptId}) async {
    final normalizedName = name.trim().toLowerCase();
    final snapshot = await _ref.get();
    final duplicate = snapshot.docs.any((doc) {
      final data = doc.data();
      final active = data['isActive'] as bool? ?? true;
      return doc.id != exceptId &&
          active &&
          data['name']?.toString().trim().toLowerCase() == normalizedName;
    });
    if (duplicate) {
      throw StateError('A branch with this name already exists');
    }
  }
}

final branchRepositoryProvider = Provider<BranchRepository?>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return null;
  return BranchRepository(
    FirebaseFirestore.instance,
    currentEffectiveMerchantId(user),
  );
});

final branchesStreamProvider = StreamProvider<List<Branch>>((ref) {
  final repository = ref.watch(branchRepositoryProvider);
  final user = ref.watch(appUserProvider).value;
  if (repository == null) return Stream.value(const <Branch>[]);
  if (user == null || user.role == 'merchant' || user.role == 'admin') {
    return repository.watchBranches();
  }
  return repository.watchBranches(
    allowedBranchIds: ref.watch(employeeAllowedBranchIdsProvider),
  );
});

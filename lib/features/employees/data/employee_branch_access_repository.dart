import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../../branches/domain/branch.dart';

class EmployeeBranchAccess {
  final String employeeId;
  final String name;
  final List<String> assignedBranchIds;

  const EmployeeBranchAccess({
    required this.employeeId,
    required this.name,
    required this.assignedBranchIds,
  });

  factory EmployeeBranchAccess.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final raw = data['assignedBranchIds'];
    final assigned = raw is List
        ? raw
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
        : <String>[];

    return EmployeeBranchAccess(
      employeeId: doc.id,
      name: data['name']?.toString().trim().isNotEmpty == true
          ? data['name'].toString().trim()
          : doc.id,
      assignedBranchIds:
          assigned.isEmpty ? const <String>[BranchIds.main] : assigned,
    );
  }
}

class EmployeeBranchAccessRepository {
  final FirebaseFirestore firestore;
  final String merchantId;

  const EmployeeBranchAccessRepository(this.firestore, this.merchantId);

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      firestore.collection('users').doc(merchantId).collection('employees');

  Stream<List<EmployeeBranchAccess>> watchAssignments() {
    return _employeesRef.orderBy('createdAt').snapshots().map((snapshot) {
      return snapshot.docs
          .map(EmployeeBranchAccess.fromDocument)
          .toList(growable: false);
    });
  }

  Future<void> updateAssignedBranches({
    required String employeeId,
    required Iterable<String> branchIds,
  }) async {
    final normalized = branchIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) {
      throw ArgumentError('Employee must be assigned to at least one branch');
    }

    // Validate that every assignment points to an active branch owned by the
    // same merchant. This prevents stale/deactivated branch IDs from being
    // persisted even if the UI submits them accidentally.
    for (final branchId in normalized) {
      final branchDoc = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .get();
      if (!branchDoc.exists || branchDoc.data() == null) {
        throw StateError('Assigned branch does not exist: $branchId');
      }
      if (branchDoc.data()!['isActive'] == false) {
        throw StateError('Assigned branch is inactive: $branchId');
      }
    }

    final employeeRef = _employeesRef.doc(employeeId);
    final rootUserRef = firestore.collection('users').doc(employeeId);

    // Keep the merchant employee record and the authenticated root user in
    // sync atomically. Firestore rules treat the root field as authoritative
    // for branch authorization after login.
    final batch = firestore.batch();
    batch.update(employeeRef, {
      'assignedBranchIds': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(rootUserRef, {
      'assignedBranchIds': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

final employeeBranchAccessRepositoryProvider =
    Provider<EmployeeBranchAccessRepository?>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return null;
  return EmployeeBranchAccessRepository(
    FirebaseFirestore.instance,
    user.merchantId ?? user.id,
  );
});

final employeeBranchAssignmentsProvider =
    StreamProvider<List<EmployeeBranchAccess>>((ref) {
  final repository = ref.watch(employeeBranchAccessRepositoryProvider);
  if (repository == null) return Stream.value(const <EmployeeBranchAccess>[]);
  return repository.watchAssignments();
});

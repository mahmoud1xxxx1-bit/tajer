import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../authentication/application/access_policy.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/order_return.dart';

/// Read-only accounting ledger for order returns.
///
/// `order_returns` is the canonical v109+ path. `returns` is kept as a
/// read-compatible legacy path because early v109 builds wrote there. Both
/// streams are merged and de-duplicated by return id so historical returns are
/// never silently dropped from reports.
class OrderReturnRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  const OrderReturnRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _canonicalRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('order_returns');

  CollectionReference<Map<String, dynamic>> get _legacyRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('returns');

  List<OrderReturn> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = data['id']?.toString() ?? doc.id;
      data['merchantId'] = data['merchantId']?.toString() ?? _merchantId;
      data['branchId'] = data['branchId']?.toString() ?? 'main';
      return OrderReturn.fromJson(data);
    }).toList();
  }

  Stream<List<OrderReturn>> watchReturns({String? branchId}) {
    Query<Map<String, dynamic>> canonical = _canonicalRef;
    Query<Map<String, dynamic>> legacy = _legacyRef;
    if (branchId != null && branchId.isNotEmpty) {
      canonical = canonical.where('branchId', isEqualTo: branchId);
      legacy = legacy.where('branchId', isEqualTo: branchId);
    }

    return Rx.combineLatest2<QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>, List<OrderReturn>>(
      canonical.snapshots(),
      legacy.snapshots(),
      (canonicalSnapshot, legacySnapshot) {
        final byId = <String, OrderReturn>{};
        // Legacy first, canonical wins if a migration/copy produced both.
        for (final value in _decode(legacySnapshot)) {
          byId[value.id] = value;
        }
        for (final value in _decode(canonicalSnapshot)) {
          byId[value.id] = value;
        }
        final values = byId.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return values;
      },
    );
  }
}

final orderReturnRepositoryProvider = Provider<OrderReturnRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return OrderReturnRepository(
    FirebaseFirestore.instance,
    currentEffectiveMerchantId(appUser),
  );
});

final branchOrderReturnsProvider =
    StreamProvider.autoDispose<List<OrderReturn>>((ref) {
  final repository = ref.watch(orderReturnRepositoryProvider);
  if (repository == null) return Stream.value(const <OrderReturn>[]);
  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return Stream.value(const <OrderReturn>[]);
  return repository.watchReturns(branchId: branchId);
});

final merchantOrderReturnsProvider =
    StreamProvider.autoDispose<List<OrderReturn>>((ref) {
  final repository = ref.watch(orderReturnRepositoryProvider);
  final policy = ref.watch(accessPolicyProvider);
  if (repository == null || !policy.isOwnerLike) {
    return Stream.value(const <OrderReturn>[]);
  }
  return repository.watchReturns();
});

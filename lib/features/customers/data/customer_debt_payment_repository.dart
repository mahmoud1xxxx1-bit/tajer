import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/customer_debt_payment.dart';

class CustomerDebtPaymentRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  const CustomerDebtPaymentRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _paymentsRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('customer_debt_payments');

  List<CustomerDebtPayment> _decode(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final payments = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['merchantId'] = data['merchantId']?.toString() ?? _merchantId;
      return CustomerDebtPayment.fromJson(data);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payments;
  }

  /// Merchant-wide history for a customer. This is the authoritative view used
  /// when reconciling a merchant-wide customer balance across branches.
  Stream<List<CustomerDebtPayment>> watchCustomerPayments(
    String customerId, {
    String? branchId,
  }) {
    Query<Map<String, dynamic>> query = _paymentsRef;
    if (branchId != null && branchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    return query.snapshots().map((snapshot) {
      return _decode(snapshot)
          .where((payment) => payment.customerId == customerId)
          .toList();
    });
  }

  /// Operational branch view for branch reports. The customer balance itself
  /// remains merchant-wide; only cash/card/transfer provenance is filtered.
  Stream<List<CustomerDebtPayment>> watchBranchPayments(String branchId) {
    return _paymentsRef
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map(_decode);
  }

  /// Complete immutable collection history for consolidated cashflow reports.
  Stream<List<CustomerDebtPayment>> watchAllPayments() {
    return _paymentsRef.snapshots().map(_decode);
  }
}

final customerDebtPaymentRepositoryProvider =
    Provider<CustomerDebtPaymentRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return CustomerDebtPaymentRepository(
    FirebaseFirestore.instance,
    currentEffectiveMerchantId(appUser),
  );
});

final customerDebtPaymentsProvider = StreamProvider.family
    .autoDispose<List<CustomerDebtPayment>, String>((ref, customerId) {
  final repository = ref.watch(customerDebtPaymentRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  final appUser = ref.watch(appUserProvider).value;
  final branchId = ref.watch(selectedBranchIdProvider);
  if (appUser?.role == 'employee' && branchId.isEmpty) {
    return Stream.value(const []);
  }
  return repository.watchCustomerPayments(
    customerId,
    branchId: appUser?.role == 'employee' ? branchId : null,
  );
});

final branchCustomerDebtPaymentsProvider =
    StreamProvider.autoDispose<List<CustomerDebtPayment>>((ref) {
  final repository = ref.watch(customerDebtPaymentRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return Stream.value(const []);
  return repository.watchBranchPayments(branchId);
});

final merchantCustomerDebtPaymentsProvider =
    StreamProvider.autoDispose<List<CustomerDebtPayment>>((ref) {
  final repository = ref.watch(customerDebtPaymentRepositoryProvider);
  final appUser = ref.watch(appUserProvider).value;
  if (repository == null) return Stream.value(const []);
  if (appUser == null || appUser.role == 'employee') {
    return Stream.value(const []);
  }
  return repository.watchAllPayments();
});

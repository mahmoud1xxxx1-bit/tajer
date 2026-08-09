import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/supplier_transaction.dart';

class SupplierTransactionRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;
  final String _branchId;

  SupplierTransactionRepository(
      this._firestore, this._merchantId, this._branchId);

  CollectionReference<Map<String, dynamic>> _transactionsRef(
          String supplierId) =>
      _firestore
          .collection('merchants')
          .doc(_merchantId)
          .collection('suppliers')
          .doc(supplierId)
          .collection('transactions');

  Stream<List<SupplierTransaction>> watchTransactions(String supplierId) {
    return _transactionsRef(supplierId)
        .withConverter(
          fromFirestore: (snapshot, _) {
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            data['branchId'] = data['branchId']?.toString() ?? 'main';
            return SupplierTransaction.fromJson(data);
          },
          toFirestore: (transaction, _) => transaction.toJson(),
        )
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data())
          .where((transaction) => transaction.branchId == _branchId)
          .toList();
    });
  }

  Future<void> addTransaction(SupplierTransaction transaction) async {
    final normalized = transaction.copyWith(branchId: _branchId);
    await _transactionsRef(normalized.supplierId)
        .doc(normalized.id)
        .set(normalized.toJson());
  }

  Future<void> updateTransaction(SupplierTransaction transaction) async {
    if (transaction.branchId != _branchId) {
      throw Exception('لا يمكن تعديل حركة مورد تابعة لفرع مختلف.');
    }
    await _transactionsRef(transaction.supplierId)
        .doc(transaction.id)
        .update(transaction.toJson());
  }
}

final supplierTransactionRepositoryProvider =
    Provider<SupplierTransactionRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  final branchId = ref.watch(selectedBranchIdProvider);
  return SupplierTransactionRepository(
    FirebaseFirestore.instance,
    currentEffectiveMerchantId(appUser),
    branchId,
  );
});

final supplierTransactionsStreamProvider =
    StreamProvider.family<List<SupplierTransaction>, String>((ref, supplierId) {
  final repo = ref.watch(supplierTransactionRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchTransactions(supplierId);
});

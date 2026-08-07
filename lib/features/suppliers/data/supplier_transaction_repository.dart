import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/supplier_transaction.dart';

class SupplierTransactionRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  SupplierTransactionRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> _transactionsRef(String supplierId) =>
      _firestore.collection('merchants').doc(_merchantId)
          .collection('suppliers').doc(supplierId)
          .collection('transactions');

  Stream<List<SupplierTransaction>> watchTransactions(String supplierId) {
    return _transactionsRef(supplierId).withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        return SupplierTransaction.fromJson(data);
      },
      toFirestore: (transaction, _) => transaction.toJson(),
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addTransaction(SupplierTransaction transaction) async {
    await _transactionsRef(transaction.supplierId).doc(transaction.id).set(transaction.toJson());
  }

  Future<void> updateTransaction(SupplierTransaction transaction) async {
    await _transactionsRef(transaction.supplierId).doc(transaction.id).update(transaction.toJson());
  }
}

final supplierTransactionRepositoryProvider = Provider<SupplierTransactionRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return SupplierTransactionRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final supplierTransactionsStreamProvider = StreamProvider.family<List<SupplierTransaction>, String>((ref, supplierId) {
  final repo = ref.watch(supplierTransactionRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchTransactions(supplierId);
});

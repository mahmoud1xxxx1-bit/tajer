import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../expenses/domain/expense.dart';
import '../domain/supplier.dart';
import '../domain/supplier_transaction.dart';

class SupplierRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  SupplierRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore
          .collection('merchants')
          .doc(_merchantId)
          .collection('suppliers');

  Query<Supplier> querySuppliers({
    String? searchQuery,
    String? folderName,
    bool? hasDebt,
    String sortBy = 'newest',
  }) {
    Query<Map<String, dynamic>> query = _suppliersRef;

    if (folderName != null &&
        folderName.isNotEmpty &&
        folderName != 'موردين عامون' &&
        folderName != 'General Suppliers') {
      query = query.where('folderName', isEqualTo: folderName);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final normalizedSearch = searchQuery.trim();
      final isPhoneSearch =
          RegExp(r'^[+0-9\s-]+$').hasMatch(normalizedSearch);
      final field = isPhoneSearch ? 'phone' : 'name';
      query = query
          .where(field, isGreaterThanOrEqualTo: normalizedSearch)
          .where(field, isLessThan: '$normalizedSearch\uf8ff')
          .orderBy(field);
    } else {
      if (hasDebt == true) {
        query = query.where('totalDebt', isGreaterThan: 0);
        query = query.orderBy('totalDebt', descending: true);
      } else {
        if (sortBy == 'debt') {
          query = query.orderBy('totalDebt', descending: true);
        } else if (sortBy == 'alpha') {
          query = query.orderBy('name', descending: false);
        } else {
          query = query.orderBy('createdAt', descending: true);
        }
      }
    }

    return query.withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['merchantId'] = data['merchantId']?.toString() ?? '';
        data['name'] = data['name']?.toString() ?? '';
        data['phone'] = data['phone']?.toString() ?? '';
        data['totalDebt'] = (data['totalDebt'] ?? 0.0).toDouble();
        if (data['createdAt'] == null) {
          data['createdAt'] = Timestamp.now();
        }
        return Supplier.fromJson(data);
      },
      toFirestore: (supplier, _) => supplier.toJson(),
    );
  }

  Stream<List<Supplier>> watchSuppliers() {
    return _suppliersRef
        .withConverter(
          fromFirestore: (snapshot, _) {
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            data['merchantId'] = data['merchantId']?.toString() ?? '';
            data['name'] = data['name']?.toString() ?? '';
            data['phone'] = data['phone']?.toString() ?? '';
            data['totalDebt'] = (data['totalDebt'] ?? 0.0).toDouble();
            if (data['createdAt'] == null) {
              data['createdAt'] = Timestamp.now();
            }
            return Supplier.fromJson(data);
          },
          toFirestore: (supplier, _) => supplier.toJson(),
        )
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _suppliersRef.doc(supplier.id).set(supplier.toJson());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _suppliersRef.doc(supplier.id).update(supplier.toJson());
  }

  Future<void> paySupplierDebt({
    required String supplierId,
    required double amountPaid,
  }) async {
    if (amountPaid <= 0) return;

    final supplierDocRef = _suppliersRef.doc(supplierId);
    await supplierDocRef.update({
      'totalDebt': FieldValue.increment(-amountPaid),
    });
  }

  /// Records the complete supplier payment lifecycle as one atomic Firestore
  /// batch: supplier debt, supplier transaction and linked expense.
  Future<void> recordSupplierPayment({
    required SupplierTransaction supplierTransaction,
    required Expense expense,
  }) async {
    final supplierRef = _suppliersRef.doc(supplierTransaction.supplierId);
    final transactionRef = supplierRef
        .collection('transactions')
        .doc(supplierTransaction.id);
    final expenseRef = _firestore
        .collection('merchants')
        .doc(_merchantId)
        .collection('expenses')
        .doc(expense.id);

    final batch = _firestore.batch();
    batch.update(supplierRef, {
      'totalDebt': FieldValue.increment(-supplierTransaction.amount),
    });
    batch.set(transactionRef, supplierTransaction.toJson());
    batch.set(expenseRef, expense.toJson());
    await batch.commit();
  }

  /// Cancels a supplier transaction and reverses its debt effect atomically.
  /// For supplier payments, the linked expense is cancelled in the same
  /// transaction. If that expense belongs to a closed shift, the whole reversal
  /// is rejected before any write is made.
  Future<void> cancelSupplierTransaction({
    required SupplierTransaction supplierTransaction,
    String? linkedExpenseId,
  }) async {
    final supplierRef = _suppliersRef.doc(supplierTransaction.supplierId);
    final transactionRef = supplierRef
        .collection('transactions')
        .doc(supplierTransaction.id);
    final expenseRef = linkedExpenseId == null
        ? null
        : _firestore
            .collection('merchants')
            .doc(_merchantId)
            .collection('expenses')
            .doc(linkedExpenseId);

    await _firestore.runTransaction((firestoreTransaction) async {
      final supplierSnapshot = await firestoreTransaction.get(supplierRef);
      final transactionSnapshot =
          await firestoreTransaction.get(transactionRef);

      if (!supplierSnapshot.exists || !transactionSnapshot.exists) {
        throw Exception('تعذر العثور على بيانات عملية المورد.');
      }

      final transactionData = transactionSnapshot.data() ?? const {};
      if (transactionData['isCancelled'] == true) return;

      final storedAmount =
          (transactionData['amount'] as num?)?.toDouble() ??
              supplierTransaction.amount;
      final storedType =
          transactionData['type']?.toString() ?? supplierTransaction.type;
      final isPayment = storedType == 'payment';

      DocumentSnapshot<Map<String, dynamic>>? expenseSnapshot;
      DocumentSnapshot<Map<String, dynamic>>? shiftSnapshot;

      if (isPayment && expenseRef != null) {
        expenseSnapshot = await firestoreTransaction.get(expenseRef);
        if (expenseSnapshot.exists) {
          final expenseData = expenseSnapshot.data() ?? const {};
          final shiftId = expenseData['shiftId']?.toString();
          if (shiftId != null && shiftId.isNotEmpty) {
            final shiftRef = _firestore.collection('shifts').doc(shiftId);
            shiftSnapshot = await firestoreTransaction.get(shiftRef);
            if (shiftSnapshot.exists &&
                shiftSnapshot.data()?['status'] == 'closed') {
              throw Exception(
                'لا يمكن إلغاء هذا السداد لأنه مرتبط بورديّة مغلقة.',
              );
            }
          }
        }
      }

      firestoreTransaction.update(transactionRef, {'isCancelled': true});
      firestoreTransaction.update(supplierRef, {
        'totalDebt': FieldValue.increment(isPayment ? storedAmount : -storedAmount),
      });

      if (isPayment &&
          expenseRef != null &&
          expenseSnapshot != null &&
          expenseSnapshot.exists &&
          expenseSnapshot.data()?['isCancelled'] != true) {
        firestoreTransaction.update(expenseRef, {'isCancelled': true});
      }
    });
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _suppliersRef.doc(supplierId).delete();
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return SupplierRepository(
      FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchSuppliers();
});

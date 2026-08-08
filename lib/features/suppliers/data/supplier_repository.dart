import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/supplier.dart';

class SupplierRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  SupplierRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('suppliers');

  Stream<List<Supplier>> watchSuppliers() {
    return _suppliersRef.withConverter(
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
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _suppliersRef.doc(supplier.id).set(supplier.toJson());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _suppliersRef.doc(supplier.id).update(supplier.toJson());
  }

  /// Legacy-compatible debt-only payment primitive. New multi-branch UI flows
  /// should prefer [settleSupplierDebt] so debt, supplier transaction and
  /// expense are committed atomically.
  Future<void> paySupplierDebt({
    required String supplierId,
    required double amountPaid,
  }) async {
    if (amountPaid <= 0) return;

    await _firestore.runTransaction((transaction) async {
      final supplierDocRef = _suppliersRef.doc(supplierId);
      final snapshot = await transaction.get(supplierDocRef);
      if (!snapshot.exists) {
        throw Exception('المورد غير موجود.');
      }

      final currentDebt = (snapshot.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
      if (amountPaid > currentDebt) {
        throw Exception('مبلغ السداد لا يمكن أن يتجاوز دين المورد المستحق.');
      }

      transaction.update(supplierDocRef, {
        'totalDebt': FieldValue.increment(-amountPaid),
      });
    });
  }

  /// Atomic accounting boundary for a supplier payment.
  ///
  /// Invariant: supplier debt, supplier ledger transaction and expense either
  /// all succeed together or none of them is persisted. If cash is taken from
  /// the shift drawer, the supplied shift must be open and belong to the same
  /// branch at commit time.
  Future<void> settleSupplierDebt({
    required String supplierId,
    required String supplierName,
    required double amountPaid,
    required String paymentMethod,
    required bool isFromShiftDrawer,
    required String branchId,
    required String transactionId,
    required String expenseId,
    required DateTime occurredAt,
    String? shiftId,
    String? creatorId,
    String? creatorName,
  }) async {
    if (amountPaid <= 0) {
      throw Exception('مبلغ السداد يجب أن يكون أكبر من صفر.');
    }
    if (branchId.trim().isEmpty) {
      throw Exception('تعذر تحديد الفرع المرتبط بالسداد.');
    }

    final supplierRef = _suppliersRef.doc(supplierId);
    final supplierTxRef = supplierRef.collection('transactions').doc(transactionId);
    final expenseRef = _firestore
        .collection('merchants')
        .doc(_merchantId)
        .collection('expenses')
        .doc(expenseId);
    final needsOpenShift = paymentMethod == 'cash' && isFromShiftDrawer;
    final shiftRef = shiftId == null || shiftId.isEmpty
        ? null
        : _firestore.collection('shifts').doc(shiftId);

    await _firestore.runTransaction((transaction) async {
      final supplierSnapshot = await transaction.get(supplierRef);
      if (!supplierSnapshot.exists || supplierSnapshot.data() == null) {
        throw Exception('المورد غير موجود.');
      }

      final currentDebt =
          (supplierSnapshot.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
      if (amountPaid > currentDebt) {
        throw Exception('مبلغ السداد لا يمكن أن يتجاوز دين المورد المستحق.');
      }

      if (needsOpenShift) {
        if (shiftRef == null) {
          throw Exception('لا يمكن خصم سداد المورد من الدرج بدون وردية مفتوحة.');
        }
        final shiftSnapshot = await transaction.get(shiftRef);
        if (!shiftSnapshot.exists || shiftSnapshot.data() == null) {
          throw Exception('الوردية المرتبطة بالسداد غير موجودة.');
        }
        final shiftData = shiftSnapshot.data()!;
        final shiftBranchId = shiftData['branchId']?.toString() ?? 'main';
        if (shiftBranchId != branchId ||
            shiftData['status']?.toString() != 'open' ||
            shiftData['endTime'] != null) {
          throw Exception('لا يمكن خصم السداد من وردية مغلقة أو فرع مختلف.');
        }
      }

      transaction.update(supplierRef, {
        'totalDebt': FieldValue.increment(-amountPaid),
      });

      transaction.set(supplierTxRef, {
        'id': transactionId,
        'supplierId': supplierId,
        'merchantId': _merchantId,
        'branchId': branchId,
        'expenseId': expenseId,
        'amount': amountPaid,
        'type': 'payment',
        'paymentMethod': paymentMethod,
        'description': 'دفعة سداد ديون للمورد${paymentMethod == 'cash' ? (isFromShiftDrawer ? ' (من الدرج)' : ' (خارج الدرج)') : ''}',
        'date': Timestamp.fromDate(occurredAt),
        'createdAt': Timestamp.fromDate(occurredAt),
        'isCancelled': false,
      });

      transaction.set(expenseRef, {
        'id': expenseId,
        'merchantId': _merchantId,
        'branchId': branchId,
        'shiftId': shiftId,
        'title': 'دفعة سداد ديون للمورد: $supplierName',
        'amount': amountPaid,
        'category': null,
        'notes': null,
        'creatorId': creatorId,
        'creatorName': creatorName ?? 'المدير',
        'isSupplierPayment': true,
        'paymentMethod': paymentMethod,
        'date': Timestamp.fromDate(occurredAt),
        'createdAt': Timestamp.fromDate(occurredAt),
        'isFromShiftDrawer': isFromShiftDrawer,
        'isCancelled': false,
        'supplierTransactionId': transactionId,
      });
    });
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _suppliersRef.doc(supplierId).delete();
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return SupplierRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchSuppliers();
});

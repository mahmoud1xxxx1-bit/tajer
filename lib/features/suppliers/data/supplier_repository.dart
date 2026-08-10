import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/supplier.dart';

class SupplierRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  SupplierRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _suppliersRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('suppliers');

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

  Future<void> addSupplierDebt({
    required String supplierId,
    required double amount,
    required String branchId,
    required String transactionId,
    required String description,
    required DateTime occurredAt,
  }) async {
    if (amount <= 0) {
      throw Exception('قيمة الدين يجب أن تكون أكبر من صفر.');
    }
    if (branchId.trim().isEmpty) {
      throw Exception('تعذر تحديد الفرع المرتبط بالدين.');
    }

    final supplierRef = _suppliersRef.doc(supplierId);
    final supplierTxRef =
        supplierRef.collection('transactions').doc(transactionId);

    await _firestore.runTransaction((transaction) async {
      final supplierSnapshot = await transaction.get(supplierRef);
      if (!supplierSnapshot.exists || supplierSnapshot.data() == null) {
        throw Exception('المورد غير موجود.');
      }

      transaction.update(supplierRef, {
        'totalDebt': FieldValue.increment(amount),
        'branchDebts.$branchId': FieldValue.increment(amount),
        'associatedBranchIds': FieldValue.arrayUnion([branchId]),
      });
      transaction.set(supplierTxRef, {
        'id': transactionId,
        'supplierId': supplierId,
        'merchantId': _merchantId,
        'branchId': branchId,
        'expenseId': null,
        'amount': amount,
        'type': 'debt_addition',
        'paymentMethod': 'cash',
        'description': description,
        'date': Timestamp.fromDate(occurredAt),
        'createdAt': Timestamp.fromDate(occurredAt),
        'isCancelled': false,
      });
    });
  }

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

      final currentDebt =
          (snapshot.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
      if (amountPaid > currentDebt) {
        throw Exception('مبلغ السداد لا يمكن أن يتجاوز دين المورد المستحق.');
      }

      transaction.update(supplierDocRef, {
        'totalDebt': FieldValue.increment(-amountPaid),
      });
    });
  }

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
    final supplierTxRef =
        supplierRef.collection('transactions').doc(transactionId);
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
          throw Exception(
              'لا يمكن خصم سداد المورد من الدرج بدون وردية مفتوحة.');
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
        'branchDebts.$branchId': FieldValue.increment(-amountPaid),
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
        'description':
            'دفعة سداد ديون للمورد${paymentMethod == 'cash' ? (isFromShiftDrawer ? ' (من الدرج)' : ' (خارج الدرج)') : ''}',
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

  Future<void> reverseSupplierPayment({
    required String supplierId,
    required String transactionId,
  }) async {
    final supplierRef = _suppliersRef.doc(supplierId);
    final supplierTxRef =
        supplierRef.collection('transactions').doc(transactionId);

    await _firestore.runTransaction((transaction) async {
      final supplierSnapshot = await transaction.get(supplierRef);
      final txSnapshot = await transaction.get(supplierTxRef);
      if (!supplierSnapshot.exists || supplierSnapshot.data() == null) {
        throw Exception('المورد غير موجود.');
      }
      if (!txSnapshot.exists || txSnapshot.data() == null) {
        throw Exception('عملية السداد غير موجودة.');
      }

      final txData = txSnapshot.data()!;
      if (txData['type']?.toString() != 'payment') {
        throw Exception('هذه العملية ليست عملية سداد مورد.');
      }
      if (txData['isCancelled'] == true) {
        throw Exception('عملية السداد ملغاة بالفعل.');
      }

      final amount = (txData['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) {
        throw Exception('قيمة عملية السداد غير صالحة للإلغاء.');
      }

      final expenseId = txData['expenseId']?.toString();
      DocumentReference<Map<String, dynamic>>? expenseRef;
      DocumentSnapshot<Map<String, dynamic>>? expenseSnapshot;
      if (expenseId != null && expenseId.isNotEmpty) {
        expenseRef = _firestore
            .collection('merchants')
            .doc(_merchantId)
            .collection('expenses')
            .doc(expenseId);
        expenseSnapshot = await transaction.get(expenseRef);
      }

      if (expenseSnapshot != null &&
          expenseSnapshot.exists &&
          expenseSnapshot.data() != null) {
        final expenseData = expenseSnapshot.data()!;
        final shiftId = expenseData['shiftId']?.toString();
        if (shiftId != null && shiftId.isNotEmpty) {
          final shiftRef = _firestore.collection('shifts').doc(shiftId);
          final shiftSnapshot = await transaction.get(shiftRef);
          if (!shiftSnapshot.exists || shiftSnapshot.data() == null) {
            throw Exception('تعذر التحقق من الوردية المرتبطة بالسداد.');
          }
          final shiftData = shiftSnapshot.data()!;
          if (shiftData['status']?.toString() != 'open' ||
              shiftData['endTime'] != null) {
            throw Exception('لا يمكن إلغاء سداد مورد مرتبط بورديه مغلقة.');
          }
          final txBranchId = txData['branchId']?.toString() ?? 'main';
          final shiftBranchId = shiftData['branchId']?.toString() ?? 'main';
          if (txBranchId != shiftBranchId) {
            throw Exception('عملية السداد مرتبطة بفرع مختلف عن الوردية.');
          }
        }
      }

      final updateData = <String, dynamic>{
        'totalDebt': FieldValue.increment(amount),
      };
      
      final txBranchIdStr = txData['branchId']?.toString();
      if (txBranchIdStr != null && txBranchIdStr.isNotEmpty) {
        updateData['branchDebts.$txBranchIdStr'] = FieldValue.increment(amount);
      }
      
      transaction.update(supplierRef, updateData);
      transaction.update(supplierTxRef, {
        'isCancelled': true,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      if (expenseRef != null &&
          expenseSnapshot != null &&
          expenseSnapshot.exists) {
        transaction.update(expenseRef, {
          'isCancelled': true,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _suppliersRef.doc(supplierId).delete();
  }
  Future<void> migrateLegacySuppliers() async {
    final suppliersSnapshot = await _suppliersRef.get();
    for (final doc in suppliersSnapshot.docs) {
      final data = doc.data();
      final hasBranchData =
          data.containsKey('associatedBranchIds') && (data['associatedBranchIds'] as List).isNotEmpty;
      if (hasBranchData) continue;

      final txSnapshot = await doc.reference.collection('transactions').get();
      final associatedBranches = <String>{};
      final branchDebts = <String, double>{};

      for (final txDoc in txSnapshot.docs) {
        final tx = txDoc.data();
        if (tx['isCancelled'] == true) continue;
        
        String branchId = tx['branchId']?.toString() ?? '';
        if (branchId.isEmpty) {
          branchId = 'legacy_unscoped';
          // Optionally, we could update the transaction to store 'legacy_unscoped' explicitly,
          // but the prompt only requires populating branchDebts and mapping it during migration calculation.
          // Wait, the prompt says "must map null/empty branchIds to the string literal 'legacy_unscoped'".
          // I will update the transaction document as well to maintain consistency.
          await txDoc.reference.update({'branchId': 'legacy_unscoped'});
        }

        associatedBranches.add(branchId);

        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final type = tx['type']?.toString();

        if (type == 'debt_addition' || type == 'purchase') {
          branchDebts[branchId] = (branchDebts[branchId] ?? 0.0) + amount;
        } else if (type == 'payment') {
          branchDebts[branchId] = (branchDebts[branchId] ?? 0.0) - amount;
        }
      }

      if (associatedBranches.isNotEmpty) {
        await doc.reference.update({
          'associatedBranchIds': associatedBranches.toList(),
          'branchDebts': branchDebts,
        });
      }
    }
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return SupplierRepository(
    FirebaseFirestore.instance,
    currentEffectiveMerchantId(appUser),
  );
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchSuppliers();
});

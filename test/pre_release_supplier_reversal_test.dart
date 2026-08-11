import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/suppliers/data/supplier_repository.dart';

void main() {
  test('supplier payment reversal restores exactly once to same branch', () async {
    final firestore = FakeFirebaseFirestore();
    final supplierRef = firestore
        .collection('merchants')
        .doc('m1')
        .collection('suppliers')
        .doc('s1');
    await supplierRef.set({
      'id': 's1',
      'merchantId': 'm1',
      'name': 'Supplier',
      'phone': '',
      'totalDebt': 100.0,
      'branchDebts': {'branch-a': 100.0},
      'associatedBranchIds': ['branch-a'],
      'createdAt': DateTime(2026, 8, 11),
    });

    final repository = SupplierRepository(firestore, 'm1');
    await repository.settleSupplierDebt(
      supplierId: 's1',
      supplierName: 'Supplier',
      amountPaid: 40,
      paymentMethod: 'transfer',
      isFromShiftDrawer: false,
      branchId: 'branch-a',
      transactionId: 'tx1',
      expenseId: 'exp1',
      occurredAt: DateTime(2026, 8, 11),
    );

    var data = (await supplierRef.get()).data()!;
    expect((data['totalDebt'] as num).toDouble(), 60);
    expect((Map<String, dynamic>.from(data['branchDebts'] as Map)['branch-a'] as num).toDouble(), 60);

    await repository.reverseSupplierPayment(
      supplierId: 's1',
      transactionId: 'tx1',
    );

    data = (await supplierRef.get()).data()!;
    expect((data['totalDebt'] as num).toDouble(), 100);
    expect((Map<String, dynamic>.from(data['branchDebts'] as Map)['branch-a'] as num).toDouble(), 100);

    await expectLater(
      repository.reverseSupplierPayment(supplierId: 's1', transactionId: 'tx1'),
      throwsA(isA<Exception>()),
      reason: 'A supplier payment must never be reversed twice.',
    );

    data = (await supplierRef.get()).data()!;
    expect((data['totalDebt'] as num).toDouble(), 100);
    expect((Map<String, dynamic>.from(data['branchDebts'] as Map)['branch-a'] as num).toDouble(), 100);
  });
}

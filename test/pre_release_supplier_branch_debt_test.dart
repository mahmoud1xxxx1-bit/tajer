import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/suppliers/data/supplier_repository.dart';

void main() {
  test('supplier payment must not exceed debt of selected branch', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('merchants').doc('m1').collection('suppliers').doc('s1').set({
      'id': 's1',
      'merchantId': 'm1',
      'name': 'Supplier',
      'phone': '',
      'totalDebt': 1000.0,
      'branchDebts': {'branch-a': 100.0, 'branch-b': 900.0},
      'associatedBranchIds': ['branch-a', 'branch-b'],
      'createdAt': DateTime(2026, 8, 11),
    });

    final repository = SupplierRepository(firestore, 'm1');

    await expectLater(
      repository.settleSupplierDebt(
        supplierId: 's1',
        supplierName: 'Supplier',
        amountPaid: 500,
        paymentMethod: 'transfer',
        isFromShiftDrawer: false,
        branchId: 'branch-a',
        transactionId: 'tx1',
        expenseId: 'exp1',
        occurredAt: DateTime(2026, 8, 11),
      ),
      throwsA(isA<Exception>()),
      reason: 'Selected branch owes only 100; repository must reject a 500 payment even when merchant-wide supplier debt is 1000.',
    );

    final supplier = await firestore.collection('merchants').doc('m1').collection('suppliers').doc('s1').get();
    final data = supplier.data()!;
    expect((data['totalDebt'] as num).toDouble(), 1000);
    final branchDebts = Map<String, dynamic>.from(data['branchDebts'] as Map);
    expect((branchDebts['branch-a'] as num).toDouble(), 100);
  });
}

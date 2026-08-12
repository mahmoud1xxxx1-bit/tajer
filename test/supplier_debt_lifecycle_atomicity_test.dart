import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/suppliers/data/supplier_repository.dart';

void main() {
  test('add and reverse supplier debt keep total and branch ledger atomic',
      () async {
    final db = FakeFirebaseFirestore();
    final supplierRef =
        db.collection('merchants').doc('m1').collection('suppliers').doc('s1');
    await supplierRef.set({
      'id': 's1',
      'merchantId': 'm1',
      'name': 'Supplier',
      'phone': '',
      'totalDebt': 20.0,
      'branchDebts': {'branch-a': 20.0},
      'associatedBranchIds': ['branch-a'],
      'createdAt': DateTime(2026, 8, 12),
    });

    final repository = SupplierRepository(db, 'm1');
    await repository.addSupplierDebt(
      supplierId: 's1',
      amount: 80,
      branchId: 'branch-a',
      transactionId: 'debt-1',
      description: 'Debt added',
      occurredAt: DateTime(2026, 8, 12),
    );

    var data = (await supplierRef.get()).data()!;
    expect((data['totalDebt'] as num).toDouble(), 100);
    expect(
      (Map<String, dynamic>.from(data['branchDebts'] as Map)['branch-a'] as num)
          .toDouble(),
      100,
    );
    final txRef = supplierRef.collection('transactions').doc('debt-1');
    var tx = (await txRef.get()).data()!;
    expect(tx['type'], 'debt_addition');
    expect(tx['branchId'], 'branch-a');
    expect(tx['isCancelled'], isFalse);

    await repository.reverseSupplierDebtAddition(
      supplierId: 's1',
      transactionId: 'debt-1',
    );

    data = (await supplierRef.get()).data()!;
    expect((data['totalDebt'] as num).toDouble(), 20);
    expect(
      (Map<String, dynamic>.from(data['branchDebts'] as Map)['branch-a'] as num)
          .toDouble(),
      20,
    );
    tx = (await txRef.get()).data()!;
    expect(tx['isCancelled'], isTrue);

    await expectLater(
      repository.reverseSupplierDebtAddition(
        supplierId: 's1',
        transactionId: 'debt-1',
      ),
      throwsA(isA<Exception>()),
    );
    data = (await supplierRef.get()).data()!;
    expect((data['totalDebt'] as num).toDouble(), 20);
    expect(
      (Map<String, dynamic>.from(data['branchDebts'] as Map)['branch-a'] as num)
          .toDouble(),
      20,
    );
  });

  test('debt reversal is rejected after later payment consumes that debt',
      () async {
    final db = FakeFirebaseFirestore();
    final supplierRef =
        db.collection('merchants').doc('m1').collection('suppliers').doc('s1');
    await supplierRef.set({
      'id': 's1',
      'merchantId': 'm1',
      'name': 'Supplier',
      'phone': '',
      'totalDebt': 0.0,
      'branchDebts': {'branch-a': 0.0},
      'associatedBranchIds': ['branch-a'],
      'createdAt': DateTime(2026, 8, 12),
    });
    final repository = SupplierRepository(db, 'm1');
    await repository.addSupplierDebt(
      supplierId: 's1',
      amount: 100,
      branchId: 'branch-a',
      transactionId: 'debt-1',
      description: 'Debt added',
      occurredAt: DateTime(2026, 8, 12),
    );
    await repository.settleSupplierDebt(
      supplierId: 's1',
      supplierName: 'Supplier',
      amountPaid: 40,
      paymentMethod: 'transfer',
      isFromShiftDrawer: false,
      branchId: 'branch-a',
      transactionId: 'pay-1',
      expenseId: 'exp-1',
      occurredAt: DateTime(2026, 8, 12),
    );

    await expectLater(
      repository.reverseSupplierDebtAddition(
        supplierId: 's1',
        transactionId: 'debt-1',
      ),
      throwsA(isA<Exception>()),
    );

    final data = (await supplierRef.get()).data()!;
    expect((data['totalDebt'] as num).toDouble(), 60);
    expect(
      (Map<String, dynamic>.from(data['branchDebts'] as Map)['branch-a'] as num)
          .toDouble(),
      60,
    );
    expect(
      (await supplierRef.collection('transactions').doc('debt-1').get())
          .data()?['isCancelled'],
      isFalse,
    );
  });
}

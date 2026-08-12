import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/models/plan_tier.dart';
import 'package:tajer/core/services/entitlement_integration.dart';
import 'package:tajer/features/suppliers/data/supplier_repository.dart';
import 'package:tajer/features/suppliers/domain/supplier.dart';
import 'package:tajer/features/suppliers/domain/supplier_transaction.dart';

void main() {
  setUp(() => EntitlementIntegration.injectTestTier(PlanTier.free));
  tearDown(EntitlementIntegration.clearTestTier);

  Supplier supplier(String id, {double debt = 100}) => Supplier(
        id: id,
        merchantId: 'm1',
        name: 'Supplier $id',
        totalDebt: debt,
        associatedBranchIds: const ['main'],
        branchDebts: {'main': debt},
        createdAt: DateTime(2026, 8, 12),
      );

  SupplierTransaction opening(String supplierId, {double amount = 100}) =>
      SupplierTransaction(
        id: 'opening-$supplierId',
        supplierId: supplierId,
        merchantId: 'm1',
        branchId: 'main',
        amount: amount,
        type: 'debt_addition',
        description: 'Opening balance',
        date: DateTime(2026, 8, 12),
        createdAt: DateTime(2026, 8, 12),
      );

  test('supplier, opening debt ledger and quota are committed together', () async {
    final db = FakeFirebaseFirestore();
    final repository = SupplierRepository(db, 'm1');
    final value = supplier('s1');

    await repository.addSupplier(
      value,
      openingTransaction: opening('s1'),
    );

    final supplierSnap = await db
        .collection('merchants')
        .doc('m1')
        .collection('suppliers')
        .doc('s1')
        .get();
    final txSnap = await supplierSnap.reference
        .collection('transactions')
        .doc('opening-s1')
        .get();
    final quotaSnap = await db
        .collection('merchants')
        .doc('m1')
        .collection('entitlement_usage')
        .doc('main_suppliers_lifetime')
        .get();

    expect(supplierSnap.exists, isTrue);
    expect(txSnap.exists, isTrue);
    expect((quotaSnap.data()?['count'] as num?)?.toInt(), 1);
  });

  test('quota rejection leaves no supplier and no orphan opening transaction', () async {
    final db = FakeFirebaseFirestore();
    final quotaRef = db
        .collection('merchants')
        .doc('m1')
        .collection('entitlement_usage')
        .doc('main_suppliers_lifetime');
    await quotaRef.set({
      'count': 5,
      'branchId': 'main',
      'resourceType': 'suppliers',
      'periodKey': 'lifetime',
    });
    final repository = SupplierRepository(db, 'm1');

    await expectLater(
      repository.addSupplier(
        supplier('blocked'),
        openingTransaction: opening('blocked'),
      ),
      throwsA(isA<Exception>()),
    );

    final supplierRef = db
        .collection('merchants')
        .doc('m1')
        .collection('suppliers')
        .doc('blocked');
    expect((await supplierRef.get()).exists, isFalse);
    expect(
      (await supplierRef.collection('transactions').doc('opening-blocked').get())
          .exists,
      isFalse,
    );
    expect((await quotaRef.get()).data()?['count'], 5);
  });
}

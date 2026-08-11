import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/suppliers/data/purchase_invoice_repository.dart';
import 'package:tajer/features/suppliers/domain/purchase_invoice.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PurchaseInvoiceRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = PurchaseInvoiceRepository(firestore, 'merchant_123');
  });

  Future<void> seedSupplier({
    double totalDebt = 100,
    Map<String, double> branchDebts = const {},
  }) async {
    await firestore
        .collection('merchants')
        .doc('merchant_123')
        .collection('suppliers')
        .doc('supp_123')
        .set({
      'id': 'supp_123',
      'merchantId': 'merchant_123',
      'name': 'Test Supplier',
      'totalDebt': totalDebt,
      'branchDebts': branchDebts,
      'branchIds': branchDebts.keys.toList(),
    });
  }

  const item = PurchaseInvoiceItem(
    itemId: 'prod_1',
    itemName: 'Ready Product 1',
    itemType: 'product',
    quantity: 10,
    unitCost: 10,
    totalCost: 100,
  );

  test('unpaid invoice increases merchant and branch debt equally', () async {
    const branchId = 'branch_A';
    await seedSupplier(totalDebt: 100, branchDebts: const {branchId: 40});

    final invoice = await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: 'supp_123',
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-001',
      items: const [item],
      totalAmount: 100,
      amountPaid: 0,
      paymentMethod: 'cash',
      isFromShiftDrawer: false,
    );

    final supplier = (await firestore
            .collection('merchants')
            .doc('merchant_123')
            .collection('suppliers')
            .doc('supp_123')
            .get())
        .data()!;
    expect((supplier['totalDebt'] as num).toDouble(), 200);
    expect(
      ((supplier['branchDebts'] as Map)['branch_A'] as num).toDouble(),
      140,
    );

    final stock = (await firestore
            .collection('merchants')
            .doc('merchant_123')
            .collection('branch_inventory')
            .doc('${branchId}_product_prod_1')
            .get())
        .data()!;
    expect((stock['quantity'] as num).toDouble(), 10);

    final saved = await firestore
        .collection('merchants')
        .doc('merchant_123')
        .collection('purchase_invoices')
        .doc(invoice.id)
        .get();
    expect(saved.exists, isTrue);
  });

  test('partial payment adds only outstanding amount to total and branch debt',
      () async {
    const branchId = 'branch_A';
    await seedSupplier(totalDebt: 100, branchDebts: const {branchId: 25});

    await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: 'supp_123',
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-002',
      items: const [item],
      totalAmount: 1000,
      amountPaid: 200,
      paymentMethod: 'transfer',
      isFromShiftDrawer: false,
    );

    final supplier = (await firestore
            .collection('merchants')
            .doc('merchant_123')
            .collection('suppliers')
            .doc('supp_123')
            .get())
        .data()!;
    expect((supplier['totalDebt'] as num).toDouble(), 900);
    expect(
      ((supplier['branchDebts'] as Map)['branch_A'] as num).toDouble(),
      825,
    );
  });

  test('cash supplier payment from drawer never changes gross cash sales',
      () async {
    const branchId = 'branch_A';
    const shiftId = 'shift_123';
    await seedSupplier(totalDebt: 100, branchDebts: const {branchId: 100});
    await firestore.collection('shifts').doc(shiftId).set({
      'id': shiftId,
      'merchantId': 'merchant_123',
      'branchId': branchId,
      'status': 'open',
      'cashSales': 500.0,
      'refundsCash': 0.0,
    });

    await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: 'supp_123',
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-003',
      items: const [item],
      totalAmount: 200,
      amountPaid: 200,
      paymentMethod: 'cash',
      isFromShiftDrawer: true,
      shiftId: shiftId,
    );

    final shift =
        (await firestore.collection('shifts').doc(shiftId).get()).data()!;
    expect((shift['cashSales'] as num).toDouble(), 500,
        reason: 'Supplier cash-out is not negative sales.');

    final expenses = await firestore
        .collection('merchants')
        .doc('merchant_123')
        .collection('expenses')
        .get();
    expect(expenses.docs.length, 1);
    expect((expenses.docs.single.data()['amount'] as num).toDouble(), 200);
    expect(expenses.docs.single.data()['isSupplierPayment'], isTrue);
    expect(expenses.docs.single.data()['isFromShiftDrawer'], isTrue);

    // Drawer equation: opening 100 + gross cash sales 500 - supplier cash-out 200.
    const opening = 100.0;
    final expectedCash = opening +
        (shift['cashSales'] as num).toDouble() -
        (expenses.docs.single.data()['amount'] as num).toDouble();
    expect(expectedCash, 400);
  });

  test('reverse invoice restores outstanding debt and inventory exactly once',
      () async {
    const branchId = 'branch_A';
    await seedSupplier(totalDebt: 100, branchDebts: const {branchId: 40});

    final invoice = await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: 'supp_123',
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-004',
      items: const [item],
      totalAmount: 100,
      amountPaid: 20,
      paymentMethod: 'transfer',
      isFromShiftDrawer: false,
    );

    await repo.reversePurchaseInvoice(invoiceId: invoice.id);

    final supplier = (await firestore
            .collection('merchants')
            .doc('merchant_123')
            .collection('suppliers')
            .doc('supp_123')
            .get())
        .data()!;
    expect((supplier['totalDebt'] as num).toDouble(), 100);
    expect(
      ((supplier['branchDebts'] as Map)['branch_A'] as num).toDouble(),
      40,
    );

    final stock = (await firestore
            .collection('merchants')
            .doc('merchant_123')
            .collection('branch_inventory')
            .doc('${branchId}_product_prod_1')
            .get())
        .data()!;
    expect((stock['quantity'] as num).toDouble(), 0);

    await expectLater(
      repo.reversePurchaseInvoice(invoiceId: invoice.id),
      throwsA(isA<Exception>()),
    );
  });

  test('reverse is rejected if later payments make branch debt insufficient',
      () async {
    const branchId = 'branch_A';
    await seedSupplier(totalDebt: 100, branchDebts: const {branchId: 100});

    final invoice = await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: 'supp_123',
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-005',
      items: const [item],
      totalAmount: 100,
      amountPaid: 0,
      paymentMethod: 'cash',
      isFromShiftDrawer: false,
    );

    // Simulate a later supplier settlement that already consumed most debt.
    await firestore
        .collection('merchants')
        .doc('merchant_123')
        .collection('suppliers')
        .doc('supp_123')
        .update({
      'totalDebt': 50.0,
      'branchDebts.$branchId': 50.0,
    });

    await expectLater(
      repo.reversePurchaseInvoice(invoiceId: invoice.id),
      throwsA(isA<Exception>()),
    );
  });

  test('drawer-linked purchase cannot be reversed after shift is closed',
      () async {
    const branchId = 'branch_A';
    const shiftId = 'shift_closed_later';
    await seedSupplier(totalDebt: 100, branchDebts: const {branchId: 100});
    await firestore.collection('shifts').doc(shiftId).set({
      'id': shiftId,
      'merchantId': 'merchant_123',
      'branchId': branchId,
      'status': 'open',
      'cashSales': 500.0,
    });

    final invoice = await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: 'supp_123',
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-006',
      items: const [item],
      totalAmount: 100,
      amountPaid: 50,
      paymentMethod: 'cash',
      isFromShiftDrawer: true,
      shiftId: shiftId,
    );

    await firestore.collection('shifts').doc(shiftId).update({
      'status': 'closed',
      'endTime': DateTime(2026, 8, 12).toIso8601String(),
    });

    await expectLater(
      repo.reversePurchaseInvoice(invoiceId: invoice.id),
      throwsA(isA<Exception>()),
    );
  });
}

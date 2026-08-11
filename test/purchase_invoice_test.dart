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

  test('createPurchaseInvoice handles unpaid invoice correctly', () async {
    const branchId = 'branch_A';
    const supplierId = 'supp_123';

    await firestore.collection('merchants').doc('merchant_123').collection('suppliers').doc(supplierId).set({
      'totalDebt': 100.0,
    });

    final invoice = await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: supplierId,
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-001',
      items: [
        const PurchaseInvoiceItem(
          itemId: 'raw_1',
          itemName: 'Raw Mat 1',
          itemType: 'raw_material',
          quantity: 10,
          unitCost: 5.0,
          totalCost: 50.0,
        ),
      ],
      totalAmount: 50.0,
      amountPaid: 0.0,
      paymentMethod: 'cash',
      isFromShiftDrawer: false,
    );

    // Assert Supplier Debt Increased by 50.0
    final suppDoc = await firestore.collection('merchants').doc('merchant_123').collection('suppliers').doc(supplierId).get();
    expect(suppDoc.data()?['totalDebt'], 150.0);

    // Assert Inventory Increased by 10
    final invDoc = await firestore.collection('merchants').doc('merchant_123').collection('branch_inventory').doc('${branchId}_raw_material_raw_1').get();
    expect(invDoc.data()?['quantity'], 10.0);

    // Assert Purchase Invoice Document Saved
    final invRec = await firestore.collection('merchants').doc('merchant_123').collection('purchase_invoices').doc(invoice.id).get();
    expect(invRec.exists, true);

    // Assert NO Expense created
    final expenses = await firestore.collection('merchants').doc('merchant_123').collection('expenses').get();
    expect(expenses.docs.isEmpty, true);
  });

  test('createPurchaseInvoice handles fully paid invoice with shift drawer correctly', () async {
    const branchId = 'branch_A';
    const supplierId = 'supp_123';
    const shiftId = 'shift_123';

    await firestore.collection('merchants').doc('merchant_123').collection('suppliers').doc(supplierId).set({
      'totalDebt': 100.0,
    });

    await firestore.collection('shifts').doc(shiftId).set({
      'branchId': branchId,
      'status': 'open',
      'cashSales': 500.0,
    });

    final invoice = await repo.createPurchaseInvoice(
      branchId: branchId,
      supplierId: supplierId,
      supplierName: 'Test Supplier',
      invoiceNumber: 'INV-002',
      items: [
        const PurchaseInvoiceItem(
          itemId: 'prod_1',
          itemName: 'Ready Product 1',
          itemType: 'product',
          quantity: 20,
          unitCost: 10.0,
          totalCost: 200.0,
        ),
      ],
      totalAmount: 200.0,
      amountPaid: 200.0,
      paymentMethod: 'cash',
      isFromShiftDrawer: true,
      shiftId: shiftId,
    );

    // Assert Supplier Debt Increased by 200 and decreased by 200 (Net 0 change)
    final suppDoc = await firestore.collection('merchants').doc('merchant_123').collection('suppliers').doc(supplierId).get();
    expect(suppDoc.data()?['totalDebt'], 100.0);

    // Assert Inventory Increased by 20
    final invDoc = await firestore.collection('merchants').doc('merchant_123').collection('branch_inventory').doc('${branchId}_product_prod_1').get();
    expect(invDoc.data()?['quantity'], 20.0);

    // Assert Shift cashSales decreased by 200
    final shiftDoc = await firestore.collection('shifts').doc(shiftId).get();
    expect(shiftDoc.data()?['cashSales'], 300.0);

    // Assert Expense created
    final expenses = await firestore.collection('merchants').doc('merchant_123').collection('expenses').get();
    expect(expenses.docs.length, 1);
    expect(expenses.docs.first.data()['amount'], 200.0);
    expect(expenses.docs.first.data()['isFromShiftDrawer'], true);
  });
}

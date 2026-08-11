import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/data/branch_aware_order_repository.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/order_return.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late BranchAwareOrderRepository repo;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('test-user').set({'role': 'merchant'});
    repo = BranchAwareOrderRepository(firestore, testUid: 'test-user');
  });

  test('partial return successfully updates inventory, shift, and customer', () async {
    const merchantId = 'merchant_123';
    const branchId = 'branch_A';
    const shiftId = 'shift_123';
    const customerId = 'cust_123';

    // Seed Shift
    await firestore.collection('shifts').doc(shiftId).set({
      'branchId': branchId,
      'status': 'open',
      'cashSales': 100.0,
      'cardTotal': 50.0,
      'transferTotal': 0.0,
      'refundsCash': 0.0,
      'refundsCard': 0.0,
      'refundsTransfer': 0.0,
    });

    // Seed Customer
    await firestore.collection('customers').doc(customerId).set({
      'branchId': branchId,
      'totalPurchases': 100.0,
      'totalDebt': 0.0,
    });

    // Seed Inventory for Ready Product
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${branchId}_product_product_1')
        .set({'quantity': 5}); // Before return, we have 5

    // Seed Inventory for Raw Material
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${branchId}_raw_material_raw_1')
        .set({'quantity': 100}); // Before return, we have 100

    // Create AppOrder in Firestore manually
    final order = AppOrder(
      id: 'order_1',
      merchantId: merchantId,
      branchId: branchId,
      customerId: customerId,
      customerName: 'Test Customer',
      total: 100.0,
      paidAmount: 100.0,
      paymentMethod: 'cash',
      status: 'completed',
      shiftId: shiftId,
      createdAt: DateTime.now(),
      items: [
        const CartItem(
          productId: 'product_1',
          productName: 'Ready Product',
          quantity: 2,
          price: 10.0,
          total: 20.0,
          isManufacturedOnDemand: false,
          lineId: 'line_1',
        ),
        const CartItem(
          productId: 'mto_1',
          productName: 'MTO Product',
          quantity: 2,
          price: 40.0,
          total: 80.0,
          isManufacturedOnDemand: true,
          lineId: 'line_2',
          historicalMtoRecipe: [
            {'rawMaterialId': 'raw_1', 'amountRequired': 5.0}
          ],
        ),
      ],
    );

    await firestore.collection('orders').doc('order_1').set(order.toJson());

    // Perform Partial Return (1 Ready Product, 1 MTO Product)
    final orderReturn = OrderReturn(
      id: 'return_1',
      originalOrderId: 'order_1',
      merchantId: merchantId,
      branchId: branchId,
      returnedItems: [
        const CartItem(
          lineId: 'line_1',
          productId: 'product_1',
          productName: 'product_1',
          quantity: 1,
          price: 10.0,
          total: 10.0,
        ),
        const CartItem(
          lineId: 'line_2',
          productId: 'mto_1',
          productName: 'mto_1',
          quantity: 1,
          price: 40.0,
          total: 40.0,
        ),
      ],
      returnedTotal: 50.0,
      returnedTax: 0.0,
      paymentMethod: 'cash',
      createdAt: DateTime.now(),
      shiftId: shiftId,
    );

    final updatedOrder = await repo.returnOrderItems(order, orderReturn);

    expect(updatedOrder.returnedQuantities['line_1'], 1);
    expect(updatedOrder.returnedQuantities['line_2'], 1);

    final orderDoc = await firestore.collection('orders').doc('order_1').get();
    expect(orderDoc.data()?['returnedQuantities']['line_1'], 1);
    expect(orderDoc.data()?['returnedQuantities']['line_2'], 1);

    // Gross sales remain immutable; the refund is a separate cash-out event.
    final shiftDoc = await firestore.collection('shifts').doc(shiftId).get();
    expect(shiftDoc.data()?['cashSales'], 100.0);
    expect(shiftDoc.data()?['refundsCash'], 50.0);
    expect(shiftDoc.data()?['cardTotal'], 50.0);
    expect(shiftDoc.data()?['refundsCard'], 0.0);
    expect(shiftDoc.data()?['transferTotal'], 0.0);
    expect(shiftDoc.data()?['refundsTransfer'], 0.0);

    // Customer lifetime purchase value is net of returns.
    final custDoc = await firestore.collection('customers').doc(customerId).get();
    expect(custDoc.data()?['totalPurchases'], 50.0);

    final p1Doc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${branchId}_product_product_1')
        .get();
    expect(p1Doc.data()?['quantity'], 6);

    final r1Doc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${branchId}_raw_material_raw_1')
        .get();
    expect(r1Doc.data()?['quantity'], 105.0);
  });

  test('partial return prevents returning more than sold', () async {
    const merchantId = 'merchant_123';
    const branchId = 'branch_A';

    final order = AppOrder(
      id: 'order_1',
      merchantId: merchantId,
      branchId: branchId,
      customerId: 'walk_in',
      customerName: 'walk_in',
      total: 10.0,
      paidAmount: 10.0,
      paymentMethod: 'cash',
      status: 'completed',
      createdAt: DateTime.now(),
      items: [
        const CartItem(
          productId: 'product_1',
          productName: 'Ready Product',
          quantity: 2,
          price: 5.0,
          total: 10.0,
          lineId: 'line_1',
        ),
      ],
    );

    await firestore.collection('orders').doc('order_1').set(order.toJson());

    final orderReturn = OrderReturn(
      id: 'return_2',
      originalOrderId: 'order_1',
      merchantId: merchantId,
      branchId: branchId,
      returnedItems: const [
        CartItem(
          lineId: 'line_1',
          productId: 'product_1',
          productName: 'Ready Product',
          quantity: 3,
          price: 5.0,
          total: 15.0,
        ),
      ],
      returnedTotal: 15.0,
      returnedTax: 0.0,
      paymentMethod: 'cash',
      createdAt: DateTime.now(),
      shiftId: 'shift_missing',
    );

    await expectLater(
      repo.returnOrderItems(order, orderReturn),
      throwsA(isA<Exception>()),
    );
  });
}

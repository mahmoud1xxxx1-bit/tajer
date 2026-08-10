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

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = BranchAwareOrderRepository(firestore);
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
            {'rawMaterialId': 'raw_1', 'amountRequired': 5.0} // 10 total consumed
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
          quantity: 1, // Returning 1 out of 2
          price: 10.0,
          total: 10.0,
        ),
        const CartItem(
          lineId: 'line_2',
          productId: 'mto_1',
          productName: 'mto_1',
          quantity: 1, // Returning 1 out of 2
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

    // Assert AppOrder returnedQuantities updated
    expect(updatedOrder.returnedQuantities['line_1'], 1);
    expect(updatedOrder.returnedQuantities['line_2'], 1);

    // Assert Firestore order updated
    final orderDoc = await firestore.collection('orders').doc('order_1').get();
    expect(orderDoc.data()?['returnedQuantities']['line_1'], 1);
    expect(orderDoc.data()?['returnedQuantities']['line_2'], 1);

    // Assert Shift cashSales decreased by 50
    final shiftDoc = await firestore.collection('shifts').doc(shiftId).get();
    expect(shiftDoc.data()?['cashSales'], 50.0);

    // Assert Customer totalPurchases decreased by 50
    final custDoc = await firestore.collection('customers').doc(customerId).get();
    expect(custDoc.data()?['totalPurchases'], 50.0);

    // Assert Inventory (Ready Product) restored by 1
    final p1Doc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${branchId}_product_product_1')
        .get();
    expect(p1Doc.data()?['quantity'], 6); // 5 + 1

    // Assert Inventory (Raw Material) restored by 5.0
    final r1Doc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${branchId}_raw_material_raw_1')
        .get();
    expect(r1Doc.data()?['quantity'], 105.0); // 100 + 5.0
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
      id: 'return_1',
      originalOrderId: 'order_1',
      merchantId: merchantId,
      branchId: branchId,
      returnedItems: [
        const CartItem(
          lineId: 'line_1',
          productId: 'product_1',
          productName: 'product_1',
          quantity: 3, // EXCEEDS SOLD (2)
          price: 5.0,
          total: 15.0,
        ),
      ],
      returnedTotal: 15.0,
      returnedTax: 0.0,
      paymentMethod: 'cash',
      createdAt: DateTime.now(),
    );

    expect(
      () => repo.returnOrderItems(order, orderReturn),
      throwsException,
    );
  });
}

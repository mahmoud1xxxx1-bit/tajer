import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/branches/data/order_branch_inventory_service.dart';

void main() {
  group('MTO Transaction Behavior Test', () {
    late FakeFirebaseFirestore firestore;
    late OrderBranchInventoryService service;
    final merchantId = 'merchant1';
    final branchId = 'main';

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = OrderBranchInventoryService(firestore);
      
      // Setup Product with recipe
      await firestore
          .collection('products')
          .doc('burger_prod')
          .set({
        'name': 'Burger',
        'isArchived': false,
        'isManufacturedOnDemand': true,
        'merchantId': merchantId,
        'recipe': [
          {'rawMaterialId': 'bun_raw', 'amountRequired': 1.0},
          {'rawMaterialId': 'patty_raw', 'amountRequired': 2.0},
        ],
      });

      // Setup Raw Materials
      await firestore
          .collection('raw_materials')
          .doc('bun_raw')
          .set({
        'name': 'Burger Bun',
        'isArchived': false,
        'merchantId': merchantId,
      });

      await firestore
          .collection('raw_materials')
          .doc('patty_raw')
          .set({
        'name': 'Beef Patty',
        'isArchived': false,
        'merchantId': merchantId,
      });

      // Setup initial branch_inventory for raw materials
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_bun_raw')
          .set({
        'branchId': branchId,
        'itemType': 'raw_material',
        'itemId': 'bun_raw',
        'quantity': 10.0,
      });

      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_patty_raw')
          .set({
        'branchId': branchId,
        'itemType': 'raw_material',
        'itemId': 'patty_raw',
        'quantity': 20.0,
      });
      
      // Allow legacy read
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('product_branch_availability')
          .doc('${branchId}_burger_prod')
          .set({'enabled': true, 'productId': 'burger_prod'});
    });

    test('Recipe Consumption: exact branch_inventory decrement', () async {
      final order = AppOrder(
        id: 'order1',
        merchantId: merchantId,
        branchId: branchId,
        customerId: 'walk_in',
        customerName: 'Walk In',
        paymentMethod: 'cash',
        total: 25.0,
        paidAmount: 25.0,
        createdAt: DateTime.now(),
        status: 'completed',
        items: [
          CartItem(
            productId: 'burger_prod',
            productName: 'Burger',
            quantity: 3,
            price: 25.0,
            total: 25.0,
            isManufacturedOnDemand: true,
          ),
        ],
      );

      await service.applySale(order, queueNumber: 1);

      // bun: 10 - (1.0 * 3) = 7.0
      final bunSnap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_bun_raw')
          .get();
      expect((bunSnap.data()?['quantity'] as num).toDouble(), 7.0);

      // patty: 20 - (2.0 * 3) = 14.0
      final pattySnap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_patty_raw')
          .get();
      expect((pattySnap.data()?['quantity'] as num).toDouble(), 14.0);
    });

    test('Atomicity: Insufficient raw inventory fails entirely', () async {
      final order = AppOrder(
        id: 'order2',
        merchantId: merchantId,
        branchId: branchId,
        customerId: 'walk_in',
        customerName: 'Walk In',
        paymentMethod: 'cash',
        total: 100.0,
        paidAmount: 100.0,
        createdAt: DateTime.now(),
        status: 'completed',
        items: [
          CartItem(
            productId: 'burger_prod',
            productName: 'Burger',
            quantity: 11, // needs 11 buns (have 10), 22 patties (have 20)
            price: 25.0,
            total: 25.0,
            isManufacturedOnDemand: true,
          ),
        ],
      );

      expect(
        () => service.applySale(order, queueNumber: 2),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Insufficient raw material inventory'))),
      );

      // Assert inventory is untouched
      final bunSnap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_bun_raw')
          .get();
      expect((bunSnap.data()?['quantity'] as num).toDouble(), 10.0);

      final pattySnap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_patty_raw')
          .get();
      expect((pattySnap.data()?['quantity'] as num).toDouble(), 20.0);
    });

    test('Cancellation: Cancelling restores exact amount', () async {
      final order = AppOrder(
        id: 'order3',
        merchantId: merchantId,
        branchId: branchId,
        customerId: 'walk_in',
        customerName: 'Walk In',
        paymentMethod: 'cash',
        total: 25.0,
        paidAmount: 25.0,
        createdAt: DateTime.now(),
        status: 'completed',
        items: [
          CartItem(
            productId: 'burger_prod',
            productName: 'Burger',
            quantity: 4,
            price: 25.0,
            total: 25.0,
            isManufacturedOnDemand: true,
          ),
        ],
      );

      await service.applySale(order, queueNumber: 3);

      var bunSnap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_bun_raw')
          .get();
      expect((bunSnap.data()?['quantity'] as num).toDouble(), 6.0); // 10 - 4

      await service.restoreForCancellation(order);

      bunSnap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_bun_raw')
          .get();
      expect((bunSnap.data()?['quantity'] as num).toDouble(), 10.0); // Restored to 10

      final pattySnap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc('${branchId}_raw_material_patty_raw')
          .get();
      expect((pattySnap.data()?['quantity'] as num).toDouble(), 20.0); // Restored to 20
    });
  });
}

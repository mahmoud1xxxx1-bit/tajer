import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajer/features/orders/data/branch_aware_order_repository.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  const merchantId = 'merchant-made-to-order';
  const productId = 'burger';
  const readyProductId = 'pepsi';
  const rawId = 'bun';
  const rawId2 = 'patty';
  const shiftId = 'shift-open';

  Future<void> seedMadeToOrderProduct(
    FakeFirebaseFirestore firestore, {
    required double mainRaw,
    required double branch2Raw,
    bool productMasterFlag = false,
  }) async {
    await firestore.collection('products').doc(productId).set({
      'id': productId,
      'merchantId': merchantId,
      'name': 'Burger',
      'price': 25.0,
      'quantity': 0,
      'recipe': [
        {'rawMaterialId': rawId, 'amountRequired': 2.0},
        {'rawMaterialId': rawId2, 'amountRequired': 1.0},
      ],
      'isManufacturedOnDemand': productMasterFlag,
      'isArchived': false,
      'taxMode': 'store',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore.collection('raw_materials').doc(rawId).set({
      'id': rawId,
      'merchantId': merchantId,
      'name': 'Bun',
      'quantity': mainRaw,
      'initialQuantity': mainRaw,
      'unit': 'piece',
      'isArchived': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore.collection('raw_materials').doc(rawId2).set({
      'id': rawId2,
      'merchantId': merchantId,
      'name': 'Patty',
      'quantity': mainRaw,
      'initialQuantity': mainRaw,
      'unit': 'piece',
      'isArchived': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('product_costs')
        .doc(rawId)
        .set({
      'merchantId': merchantId,
      'productId': rawId,
      'costPrice': 3.0,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('product_costs')
        .doc(rawId2)
        .set({
      'merchantId': merchantId,
      'productId': rawId2,
      'costPrice': 4.0,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_raw_material_$rawId')
        .set({
      'id': 'main_raw_material_$rawId',
      'merchantId': merchantId,
      'branchId': 'main',
      'itemId': rawId,
      'itemType': 'raw_material',
      'quantity': mainRaw,
      'initialQuantity': mainRaw,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('branch-2_raw_material_$rawId')
        .set({
      'id': 'branch-2_raw_material_$rawId',
      'merchantId': merchantId,
      'branchId': 'branch-2',
      'itemId': rawId,
      'itemType': 'raw_material',
      'quantity': branch2Raw,
      'initialQuantity': branch2Raw,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_raw_material_$rawId2')
        .set({
      'id': 'main_raw_material_$rawId2',
      'merchantId': merchantId,
      'branchId': 'main',
      'itemId': rawId2,
      'itemType': 'raw_material',
      'quantity': mainRaw,
      'initialQuantity': mainRaw,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('branch-2_raw_material_$rawId2')
        .set({
      'id': 'branch-2_raw_material_$rawId2',
      'merchantId': merchantId,
      'branchId': 'branch-2',
      'itemId': rawId2,
      'itemType': 'raw_material',
      'quantity': branch2Raw,
      'initialQuantity': branch2Raw,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }

  Future<void> seedShift(FakeFirebaseFirestore firestore, String branchId) {
    return firestore.collection('shifts').doc(shiftId).set({
      'id': shiftId,
      'merchantId': merchantId,
      'branchId': branchId,
      'status': 'open',
      'startTime': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }

  AppOrder madeToOrder(String id) {
    return AppOrder(
      id: id,
      merchantId: merchantId,
      customerId: 'walk_in',
      customerName: 'Walk in',
      items: const [
        CartItem(
          productId: productId,
          productName: 'Burger',
          quantity: 1,
          price: 25.0,
          total: 25.0,
          isManufacturedOnDemand: true,
        ),
      ],
      total: 25.0,
      paidAmount: 25.0,
      paymentMethod: 'cash',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  AppOrder readyOrder(String id, {int quantity = 2}) {
    return AppOrder(
      id: id,
      merchantId: merchantId,
      customerId: 'walk_in',
      customerName: 'Walk in',
      items: [
        CartItem(
          productId: readyProductId,
          productName: 'Pepsi',
          quantity: quantity,
          price: 20.0,
          total: 20.0 * quantity,
        ),
      ],
      total: 20.0 * quantity,
      paidAmount: 20.0 * quantity,
      paymentMethod: 'cash',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  Future<void> seedReadyProduct(
    FakeFirebaseFirestore firestore, {
    required double quantity,
    required double cost,
  }) async {
    await firestore.collection('products').doc(readyProductId).set({
      'id': readyProductId,
      'merchantId': merchantId,
      'name': 'Pepsi',
      'price': 20.0,
      'quantity': quantity,
      'recipe': [],
      'isManufacturedOnDemand': false,
      'isArchived': false,
      'taxMode': 'store',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('product_costs')
        .doc(readyProductId)
        .set({
      'merchantId': merchantId,
      'productId': readyProductId,
      'costPrice': cost,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_product_$readyProductId')
        .set({
      'id': 'main_product_$readyProductId',
      'merchantId': merchantId,
      'branchId': 'main',
      'itemId': readyProductId,
      'itemType': 'product',
      'quantity': quantity,
      'initialQuantity': quantity,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }

  Future<void> selectBranch(String branchId) async {
    SharedPreferences.setMockInitialValues({
      'selected_branch_$merchantId': branchId,
    });
  }

  test('ready product stores historical COGS and ignores later cost edits',
      () async {
    final firestore = FakeFirebaseFirestore();
    await selectBranch('main');
    await seedReadyProduct(firestore, quantity: 10, cost: 5);
    await seedShift(firestore, 'main');
    final repository = BranchAwareOrderRepository(firestore);

    final oldSale = await repository.createOrder(
      readyOrder('ready-old', quantity: 2),
      shiftId: shiftId,
      branchId: 'main',
    );
    expect(oldSale.items.single.costPrice, 5.0);

    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('product_costs')
        .doc(readyProductId)
        .update({'costPrice': 8.0});
    final newSale = await repository.createOrder(
      readyOrder('ready-new', quantity: 2),
      shiftId: shiftId,
      branchId: 'main',
    );

    final service = ReportsService(
      [oldSale, newSale],
      const [],
      const [],
      const [],
      const [],
      canViewCost: true,
    );
    expect(newSale.items.single.costPrice, 8.0);
    expect(service.totalRevenue, 80.0);
    expect(service.totalCOGS, 26.0);
    expect(service.netProfit, 54.0);
  });

  test(
      'main branch succeeds with sufficient raw materials and no finished stock',
      () async {
    final firestore = FakeFirebaseFirestore();
    await selectBranch('main');
    await seedMadeToOrderProduct(
      firestore,
      mainRaw: 10,
      branch2Raw: 0,
      productMasterFlag: false,
    );
    await seedShift(firestore, 'main');

    final saved = await BranchAwareOrderRepository(firestore).createOrder(
        madeToOrder('order-main'),
        shiftId: shiftId,
        branchId: 'main');

    expect(saved.id, 'order-main');
    expect(saved.items.single.costPrice, 10.0);
    expect(
      (await firestore.collection('orders').doc('order-main').get()).exists,
      isTrue,
    );
    final mainRaw = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_raw_material_$rawId')
        .get();
    expect(mainRaw.data()?['quantity'], 8.0);
    final mainRaw2 = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_raw_material_$rawId2')
        .get();
    expect(mainRaw2.data()?['quantity'], 9.0);
    final finished = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_product_$productId')
        .get();
    expect(finished.exists, isFalse);
  });

  test('main branch denies made-to-order checkout for raw material shortage',
      () async {
    final firestore = FakeFirebaseFirestore();
    await selectBranch('main');
    await seedMadeToOrderProduct(firestore, mainRaw: 1, branch2Raw: 10);
    await seedShift(firestore, 'main');

    expect(
      () => BranchAwareOrderRepository(firestore).createOrder(
          madeToOrder('order-denied'),
          shiftId: shiftId,
          branchId: 'main'),
      throwsA(predicate((error) =>
          error.toString().contains('Insufficient raw material inventory'))),
    );
    expect(
      (await firestore.collection('orders').doc('order-denied').get()).exists,
      isFalse,
    );
  });

  test('branch 2 raw shortage is isolated and does not change main raw stock',
      () async {
    final firestore = FakeFirebaseFirestore();
    await selectBranch('branch-2');
    await seedMadeToOrderProduct(firestore, mainRaw: 10, branch2Raw: 0);
    await seedShift(firestore, 'branch-2');

    expect(
      () => BranchAwareOrderRepository(firestore).createOrder(
          madeToOrder('order-branch2-denied'),
          shiftId: shiftId,
          branchId: 'branch-2'),
      throwsA(predicate((error) =>
          error.toString().contains('Insufficient raw material inventory'))),
    );
    final mainRaw = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_raw_material_$rawId')
        .get();
    final branch2Raw = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('branch-2_raw_material_$rawId')
        .get();
    expect(mainRaw.data()?['quantity'], 10.0);
    expect(branch2Raw.data()?['quantity'], 0.0);
  });

  test('sales and cancellation restore raw materials to the originating branch',
      () async {
    final firestore = FakeFirebaseFirestore();
    await selectBranch('branch-2');
    await seedMadeToOrderProduct(firestore, mainRaw: 10, branch2Raw: 6);
    await seedShift(firestore, 'branch-2');
    final repository = BranchAwareOrderRepository(firestore);

    final saved = await repository.createOrder(
      madeToOrder('order-branch2'),
      shiftId: shiftId,
      branchId: 'branch-2',
    );
    var mainRaw = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_raw_material_$rawId')
        .get();
    var branch2Raw = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('branch-2_raw_material_$rawId')
        .get();
    expect(mainRaw.data()?['quantity'], 10.0);
    expect(branch2Raw.data()?['quantity'], 4.0);

    await repository.updateOrderStatus(saved, 'cancelled');
    mainRaw = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('main_raw_material_$rawId')
        .get();
    branch2Raw = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('branch-2_raw_material_$rawId')
        .get();
    expect(mainRaw.data()?['quantity'], 10.0);
    expect(branch2Raw.data()?['quantity'], 6.0);
  });
}

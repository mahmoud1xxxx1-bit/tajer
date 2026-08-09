import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajer/features/orders/data/branch_aware_order_repository.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';

void main() {
  const merchantId = 'merchant-made-to-order';
  const productId = 'burger';
  const rawId = 'bun';
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

  Future<void> selectBranch(String branchId) async {
    SharedPreferences.setMockInitialValues({
      'selected_branch_$merchantId': branchId,
    });
  }

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

    final saved = await BranchAwareOrderRepository(firestore)
        .createOrder(madeToOrder('order-main'), shiftId: shiftId);

    expect(saved.id, 'order-main');
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
      () => BranchAwareOrderRepository(firestore)
          .createOrder(madeToOrder('order-denied'), shiftId: shiftId),
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
      () => BranchAwareOrderRepository(firestore)
          .createOrder(madeToOrder('order-branch2-denied'), shiftId: shiftId),
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

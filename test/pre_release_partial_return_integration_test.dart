import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/data/branch_aware_order_repository.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/order_return.dart';

void main() {
  CartItem line({required int qty, required double total}) => CartItem(
        lineId: 'line-1',
        productId: 'p1',
        productName: 'Product',
        quantity: qty,
        price: total / qty,
        total: total,
        taxPercentage: 15,
        isTaxInclusive: true,
      );

  Future<void> seedOrder(
    FakeFirebaseFirestore db,
    AppOrder order, {
    String shiftId = 'shift-1',
    String status = 'open',
    double? cashSales,
    double? cardTotal,
    double totalTax = 0,
  }) async {
    await db.collection('orders').doc(order.id).set(order.toJson());
    await db.collection('shifts').doc(shiftId).set({
      'id': shiftId,
      'merchantId': 'm1',
      'branchId': 'main',
      'status': status,
      'endTime': status == 'closed' ? DateTime(2026, 8, 11) : null,
      'cashSales': cashSales ?? order.splitCashAmount ?? 0.0,
      'cardTotal': cardTotal ?? order.splitNetworkAmount ?? 0.0,
      'transferTotal': 0.0,
      'refundsCash': 0.0,
      'refundsCard': 0.0,
      'refundsTransfer': 0.0,
      'totalTax': totalTax,
    });
    await db.collection('customers').doc('c1').set({
      'id': 'c1',
      'merchantId': 'm1',
      'branchId': 'main',
      'name': 'Customer',
      'phone': '',
      'totalDebt': order.isCredit ? order.total - order.paidAmount : 0.0,
      'totalPurchases': order.total,
      'orderCount': 1,
    });
  }

  test('split return preserves gross sales and records refunds proportionally',
      () async {
    final db = FakeFirebaseFirestore();
    final order = AppOrder(
      id: 'o-split',
      merchantId: 'm1',
      branchId: 'main',
      customerId: 'walk_in',
      customerName: 'Walk in',
      items: [line(qty: 2, total: 100)],
      total: 100,
      paymentMethod: 'split',
      paidAmount: 100,
      splitCashAmount: 60,
      splitNetworkAmount: 40,
      shiftId: 'shift-1',
      createdAt: DateTime(2026, 8, 11),
    );
    const grossTax = 100 - (100 / 1.15);
    await seedOrder(db, order, totalTax: grossTax);

    final returnedItem = line(qty: 1, total: 50);
    final returnedTax = 50 - (50 / 1.15);
    final ret = OrderReturn(
      id: 'r1',
      merchantId: 'm1',
      branchId: 'main',
      originalOrderId: order.id,
      returnedItems: [returnedItem],
      returnedTotal: 50,
      returnedTax: returnedTax,
      shiftId: 'shift-1',
      paymentMethod: 'split',
      createdAt: DateTime(2026, 8, 11, 12),
    );

    await BranchAwareOrderRepository(db, testUid: 'test')
        .returnOrderItems(order, ret);
    final shift = (await db.collection('shifts').doc('shift-1').get()).data()!;

    expect((shift['cashSales'] as num).toDouble(), closeTo(60, 1e-9));
    expect((shift['cardTotal'] as num).toDouble(), closeTo(40, 1e-9));
    expect((shift['refundsCash'] as num).toDouble(), closeTo(30, 1e-9));
    expect((shift['refundsCard'] as num).toDouble(), closeTo(20, 1e-9));
    expect(
      (shift['totalTax'] as num).toDouble(),
      closeTo(grossTax - returnedTax, 1e-9),
    );

    final canonicalReturn = await db
        .collection('merchants')
        .doc('m1')
        .collection('order_returns')
        .doc('r1')
        .get();
    expect(canonicalReturn.exists, isTrue);
  });

  test('later return posts to current shift and never rewrites closed sale shift',
      () async {
    final db = FakeFirebaseFirestore();
    final order = AppOrder(
      id: 'o-old',
      merchantId: 'm1',
      branchId: 'main',
      customerId: 'walk_in',
      customerName: 'Walk in',
      items: [line(qty: 2, total: 100)],
      total: 100,
      paymentMethod: 'cash',
      paidAmount: 100,
      shiftId: 'sale-shift',
      createdAt: DateTime(2026, 8, 10),
    );
    await seedOrder(
      db,
      order,
      shiftId: 'sale-shift',
      status: 'closed',
      cashSales: 100,
      totalTax: 100 - (100 / 1.15),
    );
    await db.collection('shifts').doc('return-shift').set({
      'id': 'return-shift',
      'merchantId': 'm1',
      'branchId': 'main',
      'status': 'open',
      'endTime': null,
      'cashSales': 25.0,
      'cardTotal': 0.0,
      'transferTotal': 0.0,
      'refundsCash': 0.0,
      'refundsCard': 0.0,
      'refundsTransfer': 0.0,
      'totalTax': 25 - (25 / 1.15),
    });

    final returnedTax = 50 - (50 / 1.15);
    final ret = OrderReturn(
      id: 'r-current',
      merchantId: 'm1',
      branchId: 'main',
      originalOrderId: order.id,
      returnedItems: [line(qty: 1, total: 50)],
      returnedTotal: 50,
      returnedTax: returnedTax,
      shiftId: 'return-shift',
      paymentMethod: 'cash',
      createdAt: DateTime(2026, 8, 12),
    );

    await BranchAwareOrderRepository(db, testUid: 'test')
        .returnOrderItems(order, ret);

    final oldShift =
        (await db.collection('shifts').doc('sale-shift').get()).data()!;
    expect((oldShift['cashSales'] as num).toDouble(), 100);
    expect((oldShift['refundsCash'] as num).toDouble(), 0);

    final currentShift =
        (await db.collection('shifts').doc('return-shift').get()).data()!;
    expect((currentShift['cashSales'] as num).toDouble(), 25);
    expect((currentShift['refundsCash'] as num).toDouble(), 50);
  });

  test('return rejects a closed or wrong-branch posting shift', () async {
    final db = FakeFirebaseFirestore();
    final order = AppOrder(
      id: 'o-guard',
      merchantId: 'm1',
      branchId: 'main',
      customerId: 'walk_in',
      customerName: 'Walk in',
      items: [line(qty: 2, total: 100)],
      total: 100,
      paymentMethod: 'cash',
      paidAmount: 100,
      shiftId: 'sale-shift',
      createdAt: DateTime(2026, 8, 10),
    );
    await seedOrder(db, order, shiftId: 'sale-shift', status: 'closed');

    final ret = OrderReturn(
      id: 'r-closed',
      merchantId: 'm1',
      branchId: 'main',
      originalOrderId: order.id,
      returnedItems: [line(qty: 1, total: 50)],
      returnedTotal: 50,
      returnedTax: 50 - (50 / 1.15),
      shiftId: 'sale-shift',
      paymentMethod: 'cash',
      createdAt: DateTime(2026, 8, 12),
    );

    await expectLater(
      BranchAwareOrderRepository(db, testUid: 'test')
          .returnOrderItems(order, ret),
      throwsA(isA<Exception>()),
    );
  });

  test('credit partial return cannot reduce debt below zero after prior payment',
      () async {
    final db = FakeFirebaseFirestore();
    final order = AppOrder(
      id: 'o-credit',
      merchantId: 'm1',
      branchId: 'main',
      customerId: 'c1',
      customerName: 'Customer',
      items: [line(qty: 2, total: 100)],
      total: 100,
      paymentMethod: 'cash',
      isCredit: true,
      paidAmount: 80,
      shiftId: 'shift-1',
      createdAt: DateTime(2026, 8, 11),
    );
    await seedOrder(db, order);

    final ret = OrderReturn(
      id: 'r2',
      merchantId: 'm1',
      branchId: 'main',
      originalOrderId: order.id,
      returnedItems: [line(qty: 1, total: 50)],
      returnedTotal: 50,
      returnedTax: 50 - (50 / 1.15),
      shiftId: 'shift-1',
      paymentMethod: 'cash',
      createdAt: DateTime(2026, 8, 11, 12),
    );

    await expectLater(
      BranchAwareOrderRepository(db, testUid: 'test')
          .returnOrderItems(order, ret),
      throwsA(isA<Exception>()),
      reason:
          'Only 20 remains unpaid; a 50 credit return must not create negative customer debt.',
    );
    final customer = (await db.collection('customers').doc('c1').get()).data()!;
    expect((customer['totalDebt'] as num).toDouble(), 20);
  });
}

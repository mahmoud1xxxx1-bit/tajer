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

  Future<void> seedOrder(FakeFirebaseFirestore db, AppOrder order) async {
    await db.collection('orders').doc(order.id).set(order.toJson());
    await db.collection('shifts').doc('shift-1').set({
      'id': 'shift-1',
      'merchantId': 'm1',
      'branchId': 'main',
      'status': 'open',
      'cashSales': order.splitCashAmount ?? 0.0,
      'cardTotal': order.splitNetworkAmount ?? 0.0,
      'transferTotal': 0.0,
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

  test('split partial return must reverse cash and card proportionally', () async {
    final db = FakeFirebaseFirestore();
    final order = AppOrder(
      id: 'o-split', merchantId: 'm1', branchId: 'main',
      customerId: 'walk_in', customerName: 'Walk in',
      items: [line(qty: 2, total: 100)], total: 100,
      paymentMethod: 'split', paidAmount: 100,
      splitCashAmount: 60, splitNetworkAmount: 40,
      shiftId: 'shift-1', createdAt: DateTime(2026, 8, 11),
    );
    await seedOrder(db, order);

    final returnedItem = line(qty: 1, total: 50);
    final ret = OrderReturn(
      id: 'r1', merchantId: 'm1', branchId: 'main', originalOrderId: order.id,
      returnedItems: [returnedItem], returnedTotal: 50,
      returnedTax: 50 - (50 / 1.15), shiftId: 'shift-1',
      paymentMethod: 'split', createdAt: DateTime(2026, 8, 11, 12),
    );

    await BranchAwareOrderRepository(db, testUid: 'test').returnOrderItems(order, ret);
    final shift = (await db.collection('shifts').doc('shift-1').get()).data()!;
    expect((shift['cashSales'] as num).toDouble(), closeTo(30, 1e-9));
    expect((shift['cardTotal'] as num).toDouble(), closeTo(20, 1e-9));
  });

  test('credit partial return cannot reduce debt below zero after prior payment', () async {
    final db = FakeFirebaseFirestore();
    final order = AppOrder(
      id: 'o-credit', merchantId: 'm1', branchId: 'main',
      customerId: 'c1', customerName: 'Customer',
      items: [line(qty: 2, total: 100)], total: 100,
      paymentMethod: 'cash', isCredit: true, paidAmount: 80,
      shiftId: 'shift-1', createdAt: DateTime(2026, 8, 11),
    );
    await seedOrder(db, order);

    final returnedItem = line(qty: 1, total: 50);
    final ret = OrderReturn(
      id: 'r2', merchantId: 'm1', branchId: 'main', originalOrderId: order.id,
      returnedItems: [returnedItem], returnedTotal: 50,
      returnedTax: 50 - (50 / 1.15), shiftId: 'shift-1',
      paymentMethod: 'cash', createdAt: DateTime(2026, 8, 11, 12),
    );

    await expectLater(
      BranchAwareOrderRepository(db, testUid: 'test').returnOrderItems(order, ret),
      throwsA(isA<Exception>()),
      reason: 'Only 20 remains unpaid; a 50 credit return must not create negative customer debt.',
    );
    final customer = (await db.collection('customers').doc('c1').get()).data()!;
    expect((customer['totalDebt'] as num).toDouble(), 20);
  });
}

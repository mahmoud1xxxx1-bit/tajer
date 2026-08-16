import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tajer/firebase_options.dart';

import 'package:tajer/features/orders/data/order_repository.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';

bool _emulatorsConfigured = false;

Future<String> _login() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (!_emulatorsConfigured) {
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    _emulatorsConfigured = true;
  }
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return auth.currentUser!.uid;
  try {
    await auth.signInWithEmailAndPassword(email: 'qa-orders@test.local', password: 'password123');
  } catch (_) {
    try {
      await auth.createUserWithEmailAndPassword(email: 'qa-orders@test.local', password: 'password123');
    } catch (_) {
      await auth.signInWithEmailAndPassword(email: 'qa-orders@test.local', password: 'password123');
    }
  }
  return auth.currentUser!.uid;
}

Future<void> _deleteQuery(Query<Map<String, dynamic>> q) async {
  final s = await q.get();
  for (final d in s.docs) { await d.reference.delete(); }
}

AppOrder _cashOrder({
  required String id,
  required String merchantId,
  required String productId,
  required double total,
}) {
  return AppOrder(
    id: id,
    merchantId: merchantId,
    creatorId: merchantId,
    creatorName: 'QA',
    createdAt: DateTime.now(),
    paymentMethod: 'cash',
    total: total,
    paidAmount: total,
    isCredit: false,
    customerId: 'walk_in',
    customerName: 'Walk-in',
    items: [CartItem(
      productId: productId,
      productName: 'QA Order Product',
      quantity: 1,
      price: total,
      total: total,
      costPrice: 3.0,
    )],
    status: 'completed',
  );
}

Future<void> _seedProductAndShift(FirebaseFirestore db, String merchantId,
    String productId, String shiftId, double qty) async {
  await db.collection('products').doc(productId).set({
    'id': productId,
    'merchantId': merchantId,
    'name': 'QA Order Product',
    'price': 10.0,
    'cost': 3.0,
    'quantity': qty,
    'isArchived': false,
    'isManufacturedOnDemand': false,
    'recipe': <dynamic>[],
  });
  await db.collection('shifts').doc(shiftId).set({
    'id': shiftId,
    'merchantId': merchantId,
    'employeeId': merchantId,
    'employeeName': 'QA',
    'startTime': FieldValue.serverTimestamp(),
    'startCash': 0.0,
    'status': 'open',
    'cashSales': 0.0,
    'cardTotal': 0.0,
    'transferTotal': 0.0,
    'refundsCash': 0.0,
    'refundsCard': 0.0,
    'refundsTransfer': 0.0,
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 3/34 - invoice cancellation reverses stock once and records refund once', (tester) async {
    final merchantId = await _login();
    final db = FirebaseFirestore.instance;
    final repo = OrderRepository(db);
    await _deleteQuery(db.collection('orders').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('shifts').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('merchants').doc(merchantId).collection('inventory_logs'));

    const productId = 'qa_cancel_product';
    const shiftId = 'qa_cancel_shift';
    const orderId = 'qa_cancel_order';
    await _seedProductAndShift(db, merchantId, productId, shiftId, 10);

    final order = _cashOrder(id: orderId, merchantId: merchantId, productId: productId, total: 100);
    await repo.createOrder(order, shiftId: shiftId);

    var product = await db.collection('products').doc(productId).get();
    var shift = await db.collection('shifts').doc(shiftId).get();
    expect((product.data()?['quantity'] as num).toDouble(), 9.0);
    expect((shift.data()?['cashSales'] as num).toDouble(), 100.0);

    await repo.updateOrderStatus(order, 'cancelled');

    product = await db.collection('products').doc(productId).get();
    shift = await db.collection('shifts').doc(shiftId).get();
    final cancelled = await db.collection('orders').doc(orderId).get();
    expect(cancelled.data()?['status'], 'cancelled');
    expect((product.data()?['quantity'] as num).toDouble(), 10.0,
        reason: 'Cancellation must restore exactly one sold unit');
    expect((shift.data()?['refundsCash'] as num).toDouble(), 100.0,
        reason: 'Cancellation must add one cash refund event');

    final logsAfterFirst = await db.collection('merchants').doc(merchantId)
        .collection('inventory_logs').where('productId', isEqualTo: productId).get();
    final countAfterFirst = logsAfterFirst.docs.length;

    await repo.updateOrderStatus(order, 'cancelled');
    product = await db.collection('products').doc(productId).get();
    shift = await db.collection('shifts').doc(shiftId).get();
    final logsAfterSecond = await db.collection('merchants').doc(merchantId)
        .collection('inventory_logs').where('productId', isEqualTo: productId).get();

    expect((product.data()?['quantity'] as num).toDouble(), 10.0,
        reason: 'Repeated cancellation must not restore stock twice');
    expect((shift.data()?['refundsCash'] as num).toDouble(), 100.0,
        reason: 'Repeated cancellation must not record refund twice');
    expect(logsAfterSecond.docs.length, countAfterFirst,
        reason: 'Repeated cancellation must not create a second reversal log');
  });

  testWidgets('TEST 14/34 - 10 concurrent sales preserve order count stock and shift totals', (tester) async {
    final merchantId = await _login();
    final db = FirebaseFirestore.instance;
    final repo = OrderRepository(db);
    await _deleteQuery(db.collection('orders').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('shifts').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('merchants').doc(merchantId).collection('inventory_logs'));

    const productId = 'qa_concurrent_sales_product';
    const shiftId = 'qa_concurrent_sales_shift';
    await _seedProductAndShift(db, merchantId, productId, shiftId, 100);

    final futures = <Future<AppOrder>>[];
    for (var i = 0; i < 10; i++) {
      final order = _cashOrder(
        id: 'qa_concurrent_sale_$i',
        merchantId: merchantId,
        productId: productId,
        total: 10,
      );
      futures.add(repo.createOrder(order, shiftId: shiftId));
    }
    await Future.wait(futures);

    final orders = await db.collection('orders').where('merchantId', isEqualTo: merchantId).get();
    final product = await db.collection('products').doc(productId).get();
    final shift = await db.collection('shifts').doc(shiftId).get();

    expect(orders.docs.length, 10, reason: 'Every concurrent sale must create exactly one distinct order');
    expect(orders.docs.map((d) => d.id).toSet().length, 10, reason: 'No duplicate order document IDs');
    expect((product.data()?['quantity'] as num).toDouble(), 90.0,
        reason: '100 - 10 concurrent one-unit sales = 90');
    expect((shift.data()?['cashSales'] as num).toDouble(), 100.0,
        reason: '10 sales x 10 cash = 100 shift cash sales');

    final logs = await db.collection('merchants').doc(merchantId).collection('inventory_logs')
        .where('productId', isEqualTo: productId).get();
    expect(logs.docs.length, 10, reason: 'Each sale must leave one inventory movement');
  });
}

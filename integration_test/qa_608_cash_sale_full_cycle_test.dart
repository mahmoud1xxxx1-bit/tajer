import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajer/main.dart' as app;
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(80)
      .toList();
  throw TimeoutException('Finder not found: ${finder.description}; visible=$texts');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 1/34 - full cash sale cycle through Tajer UI and report',
      (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 3));

    // TEST 1 validates the sale/accounting flow, not StartupScreen authentication.
    // Authenticate directly against the configured Auth emulator so an unrelated
    // Startup lifecycle race cannot mask the sale assertions.
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    expect(auth.currentUser, isNotNull, reason: 'QA auth bootstrap must succeed');
    final uid = auth.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    await db.collection('users').doc(uid).set({
      'id': uid,
      'name': 'Guest QA Merchant',
      'role': 'merchant',
      'plan': 'guest',
      'isAnonymous': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    const shiftId = 'qa608_cash_shift';
    const productId = 'qa608_cash_product';

    await db.collection('shifts').doc(shiftId).set({
      'id': shiftId,
      'merchantId': uid,
      'employeeId': uid,
      'employeeName': 'Guest QA',
      'startTime': FieldValue.serverTimestamp(),
      'startCash': 100.0,
      'status': 'open',
      'cashSales': 0.0,
      'cardTotal': 0.0,
      'transferTotal': 0.0,
      'refundsCash': 0.0,
    });

    await db.collection('products').doc(productId).set({
      'id': productId,
      'merchantId': uid,
      'name': 'QA608 Cash Product',
      'price': 150.0,
      'cost': 50.0,
      'costPrice': 50.0,
      'quantity': 10,
      'categoryId': 'qa608_category',
      'isTaxInclusive': true,
      'taxPercentage': 15.0,
      'isManufacturedOnDemand': false,
      'isArchived': false,
      'recipe': <dynamic>[],
      'modifiers': <dynamic>[],
      'barcode': '608000001',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await tester.pumpAndSettle(const Duration(seconds: 3));

    final pos = find.byIcon(Icons.point_of_sale);
    await pumpUntilFound(tester, pos);
    await tester.tap(pos.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final product = find.text('QA608 Cash Product');
    await pumpUntilFound(tester, product);
    await tester.tap(product.first);
    await tester.pumpAndSettle();

    final payTotal = find.byWidgetPredicate((w) =>
        w is Text &&
        w.data != null &&
        (w.data!.contains('دفع الإجمالي') || w.data!.contains('Pay Total')));
    await pumpUntilFound(tester, payTotal);
    await tester.tap(payTotal.last);
    await tester.pumpAndSettle();

    final confirm = find.byWidgetPredicate((w) =>
        w is Text &&
        (w.data == 'تأكيد وإصدار الفاتورة' ||
            w.data == 'Confirm & Issue Invoice'));
    await pumpUntilFound(tester, confirm);
    await tester.tap(confirm.first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final ordersSnap = await db
        .collection('orders')
        .where('merchantId', isEqualTo: uid)
        .get();
    expect(ordersSnap.docs.length, 1,
        reason: 'Exactly one cash order must be created');

    final rawOrder = Map<String, dynamic>.from(ordersSnap.docs.single.data());
    rawOrder['id'] = ordersSnap.docs.single.id;
    final order = AppOrder.fromJson(rawOrder);
    expect(order.total, 150.0);
    expect(order.paymentMethod, 'cash');
    expect(order.status, isNot('cancelled'));

    final productAfter = await db.collection('products').doc(productId).get();
    expect((productAfter.data()?['quantity'] as num).toDouble(), 9.0,
        reason: 'Stock must decrease from 10 to 9');

    final shiftAfter = await db.collection('shifts').doc(shiftId).get();
    expect((shiftAfter.data()?['cashSales'] as num).toDouble(), 150.0,
        reason: 'Shift Cash Sales must increase by the cash sale amount');

    final inventoryLogs = await db
        .collection('merchants')
        .doc(uid)
        .collection('inventory_logs')
        .where('productId', isEqualTo: productId)
        .get();
    expect(inventoryLogs.docs.length, 1,
        reason: 'Sale must create one inventory movement for the product');
    expect(
      (inventoryLogs.docs.single.data()['changeQuantity'] as num).toDouble(),
      -1.0,
    );

    final report = ReportsService([order], const [], const [], const [], const []);
    expect(report.totalRevenue, 150.0,
        reason: 'The actual created order must appear as 150 revenue in reports');
    expect(report.paymentMethodsBreakdown['cash'], 150.0,
        reason: 'Report cash payment breakdown must equal the cash sale');
    expect(report.getDailySales().single.amount, 150.0);
  });
}
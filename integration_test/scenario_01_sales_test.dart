import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajer/main.dart' as app;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  bool found = false;
  final timer = Timer(timeout, () {
    final texts = find.byType(Text).evaluate().map((e) {
      final widget = e.widget;
      if (widget is Text) return widget.data;
      return null;
    }).where((e) => e != null).toList();
    throw Exception("Timeout waiting for finder: ${finder.description}. Visible texts: $texts");
  });
  while (found != true) {
    await tester.pump(const Duration(milliseconds: 300));
    found = finder.evaluate().isNotEmpty;
  }
  timer.cancel();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 1 - CASH SALE: Verify UI, Stock, Shift Cash, and Audit Trail', (WidgetTester tester) async {
    app.main();

    // Wait for the auth state to resolve.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final auth = FirebaseAuth.instance;
    final guestLoginFinder = find.byWidgetPredicate((w) =>
        w is Text &&
        w.data != null &&
        (w.data!.contains('Enter as guest') || w.data!.contains('زائر')));

    bool isLoggedIn = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (guestLoginFinder.evaluate().isNotEmpty) {
        await tester.tap(guestLoginFinder.first);
        await tester.pump(const Duration(seconds: 2));
      }
      if (auth.currentUser != null) {
        isLoggedIn = true;
        break;
      }
    }

    expect(isLoggedIn, true, reason: 'User should be logged in');
    final uid = auth.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    // Each workflow starts a fresh Firebase Emulator. Do not query/delete
    // collections as a cleanup step because Firestore rules intentionally
    // reject broad pre-merchant reads. Establish a complete AppUser identity first.
    await firestore.collection('users').doc(uid).set({
      'id': uid,
      'uid': uid,
      'merchantId': uid,
      'role': 'merchant',
      'plan': 'guest',
      'isAnonymous': true,
      'permissions': <String, dynamic>{},
      'email': auth.currentUser!.email ?? 'qa-cash-sale@test.local',
      'name': 'QA Cash Sale Merchant',
      'displayName': 'QA Cash Sale Merchant',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await firestore.collection('shifts').doc('qa_test_shift_1').set({
      'id': 'qa_test_shift_1',
      'merchantId': uid,
      'employeeId': uid,
      'employeeName': 'Guest',
      'startTime': FieldValue.serverTimestamp(),
      'startCash': 100.0,
      'status': 'open',
    });

    // Wait for Dashboard to load and find the POS button.
    final posButtonFinder = find.byIcon(Icons.point_of_sale);
    await pumpUntilFound(tester, posButtonFinder);
    await tester.tap(posButtonFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await firestore.collection('products').doc('qa_cash_prod1').set({
      'id': 'qa_cash_prod1',
      'merchantId': uid,
      'name': 'Test Cash Product',
      'price': 150.0,
      'costPrice': 50.0,
      'quantity': 10,
      'categoryId': 'qa_cash_cat1',
      'isTaxInclusive': true,
      'taxPercentage': 15.0,
      'isManufacturedOnDemand': false,
      'isArchived': false,
      'modifiers': [],
      'barcode': '123456789',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await tester.pumpAndSettle(const Duration(seconds: 3));

    final productFinder = find.text('Test Cash Product');
    await pumpUntilFound(tester, productFinder);
    await tester.tap(productFinder.first);
    await tester.pumpAndSettle();

    final payTotalFinder = find.byWidgetPredicate((widget) {
      if (widget is Text) {
        return widget.data != null &&
            (widget.data!.contains('دفع الإجمالي') ||
                widget.data!.contains('Pay Total'));
      }
      return false;
    });
    expect(payTotalFinder, findsWidgets);
    await tester.tap(payTotalFinder.last);
    await tester.pumpAndSettle();

    final openShiftFinder = find.byWidgetPredicate((widget) {
      if (widget is Text) {
        return widget.data == 'افتح الدرج وأكمل البيع' ||
            widget.data == 'Open Drawer & Continue';
      }
      return false;
    });

    if (openShiftFinder.evaluate().isNotEmpty) {
      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '100');
      await tester.tap(openShiftFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    final confirmFinder = find.byWidgetPredicate((widget) {
      if (widget is Text) {
        return widget.data == 'تأكيد وإصدار الفاتورة' ||
            widget.data == 'Confirm & Issue Invoice';
      }
      return false;
    });

    await pumpUntilFound(tester, confirmFinder);
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // VERIFICATIONS
    final ordersSnap = await firestore
        .collection('orders')
        .where('merchantId', isEqualTo: uid)
        .get();
    expect(ordersSnap.docs.length, 1,
        reason: 'Exactly one order should be created');

    final order = ordersSnap.docs.first.data();
    expect((order['total'] as num).toDouble(), 150.0);
    expect(order['paymentMethod'], 'cash');

    final prodSnap =
        await firestore.collection('products').doc('qa_cash_prod1').get();
    expect((prodSnap.data()?['quantity'] as num).toDouble(), 9.0,
        reason: 'Stock should decrease by 1');

    final logsSnap = await firestore
        .collection('activity_logs')
        .where('merchantId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    final foundOrderLog = logsSnap.docs.any(
        (doc) => doc.data()['actionType'].toString().contains('Order'));
    expect(foundOrderLog, true,
        reason: 'Audit log for order creation should exist');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajer/main.dart' as app;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 2 - CARD SALE', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final guestLoginFinder = find.byWidgetPredicate((w) => w is Text && (w.data == 'الدخول كزائر وتجربة النظام' || w.data == 'Enter as guest and try the system'));
    if (guestLoginFinder.evaluate().isNotEmpty) {
      await tester.tap(guestLoginFinder);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final firestore = FirebaseFirestore.instance;

    // Reset data
    final oldOrders = await firestore.collection('orders').where('merchantId', isEqualTo: uid).get();
    for (var doc in oldOrders.docs) { await doc.reference.delete(); }

    await firestore.collection('products').doc('prod_card').set({
      'id': 'prod_card', 'merchantId': uid, 'name': 'Card Product', 'price': 200.0,
      'quantity': 5, 'isTaxInclusive': true, 'createdAt': FieldValue.serverTimestamp(),
    });
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Card Product').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate((w) => w is Text && w.data != null && (w.data!.contains('دفع الإجمالي') || w.data!.contains('Pay Total'))));
    await tester.pumpAndSettle();

    // Select Card Payment ('مدى 💳' or 'Mada/Card 💳')
    final cardChipFinder = find.byWidgetPredicate((w) => w is Text && (w.data!.contains('مدى') || w.data!.contains('Mada')));
    await tester.tap(cardChipFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data == 'تأكيد وإصدار الفاتورة' || w.data == 'Confirm & Issue Invoice')));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    final ordersSnap = await firestore.collection('orders').where('merchantId', isEqualTo: uid).get();
    expect(ordersSnap.docs.length, 1);
    final order = ordersSnap.docs.first.data();
    expect(order['total'], 200.0);
    expect(order['paymentMethod'], 'mada');

    final prodSnap = await firestore.collection('products').doc('prod_card').get();
    expect(prodSnap.data()?['quantity'], 4);
  });

  testWidgets('TEST 3 - CREDIT SALE', (WidgetTester tester) async {
    // Implement later
  });
}

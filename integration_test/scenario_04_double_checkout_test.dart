import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tajer/main.dart' as app;
import 'package:uuid/uuid.dart';

import 'package:tajer/features/orders/domain/order.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 9: Double Checkout / Rapid Tap', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Login
    final auth = FirebaseAuth.instance;
    await Future.delayed(const Duration(seconds: 2));
    try {
      await auth.signInWithEmailAndPassword(email: 'test@admin.com', password: 'password123');
    } catch(e) {}
    
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final firestore = FirebaseFirestore.instance;
    final uid = auth.currentUser!.uid;

    // Clear old orders
    final oldOrders = await firestore.collection('orders').where('merchantId', isEqualTo: uid).get();
    for (var doc in oldOrders.docs) { await doc.reference.delete(); }

    // Tap a product (Assuming we have one, or we inject one first)
    await firestore.collection('products').doc('testProd1').set({
      'id': 'testProd1', 'merchantId': uid, 'name': 'Test', 'price': 50.0, 'cost': 20.0, 'quantity': 100, 'isArchived': false, 'isManufacturedOnDemand': false,
    });
    
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap product 
    final productFinder = find.text('Test');
    if (productFinder.evaluate().isNotEmpty) {
      await tester.tap(productFinder.first);
      await tester.pumpAndSettle();
      
      // Tap pay
      final payButton = find.byType(ElevatedButton);
      await tester.tap(payButton.last); // Assuming last is the pay button
      await tester.pumpAndSettle();
      
      // In checkout screen, tap Cash
      final cashButton = find.text('Cash');
      if (cashButton.evaluate().isNotEmpty) {
        await tester.tap(cashButton.first);
        await tester.pumpAndSettle();
        
        // Tap "Pay 50" (Confirm)
        final confirmFinder = find.byType(ElevatedButton).last;
        
        // RAPID TAPPING (5 times) without pumping in between
        for(int i=0; i<5; i++) {
          await tester.tap(confirmFinder);
        }
        
        // Now pump and settle to let all events process
        await tester.pumpAndSettle();
        
        // Verify only ONE order exists in Firestore
        final afterOrders = await firestore.collection('orders').where('merchantId', isEqualTo: uid).get();
        expect(afterOrders.docs.length, 1, reason: "Double checkout failed: Found ${afterOrders.docs.length} orders instead of 1.");
      }
    }

    print("Double Checkout Test Completed");
  });
}

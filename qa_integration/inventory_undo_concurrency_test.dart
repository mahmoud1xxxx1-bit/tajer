import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tajer/firebase_options.dart';

import 'package:tajer/features/inventory_log/data/inventory_log_repository.dart';
import 'package:tajer/features/inventory_log/domain/inventory_log.dart';
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
  if (auth.currentUser == null) {
    try {
      await auth.signInWithEmailAndPassword(email: 'qa-inventory@test.local', password: 'password123');
    } catch (_) {
      try {
        await auth.createUserWithEmailAndPassword(email: 'qa-inventory@test.local', password: 'password123');
      } catch (_) {
        await auth.signInWithEmailAndPassword(email: 'qa-inventory@test.local', password: 'password123');
      }
    }
  }
  final uid = auth.currentUser!.uid;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'id': uid,
    'name': 'QA Inventory Merchant',
    'email': 'qa-inventory@test.local',
    'role': 'merchant',
    'plan': 'premium',
    'isAnonymous': false,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return uid;
}

Future<InventoryLog> _createAdjustment({
  required FirebaseFirestore db,
  required InventoryLogRepository repo,
  required String merchantId,
  required String productId,
  required double from,
  required double to,
  required String reason,
}) async {
  await db.collection('products').doc(productId).update({
    'quantity': to,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  await repo.logChange(
    productId: productId,
    productName: 'QA Inventory Product',
    previousQuantity: from,
    newQuantity: to,
    reason: reason,
    userEmail: 'qa@test.local',
    userName: 'QA',
    itemType: 'product',
  );
  final snap = await db.collection('merchants').doc(merchantId).collection('inventory_logs')
      .where('productId', isEqualTo: productId)
      .orderBy('date', descending: true).limit(1).get();
  return InventoryLog.fromJson({...snap.docs.first.data(), 'id': snap.docs.first.id});
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 6/34 - inventory undo restores quantity atomically and is idempotent', (tester) async {
    final merchantId = await _login();
    final db = FirebaseFirestore.instance;
    final repo = InventoryLogRepository(db, merchantId);
    const productId = 'qa_inventory_undo_product';

    await db.collection('products').doc(productId).set({
      'id': productId,
      'merchantId': merchantId,
      'name': 'QA Inventory Product',
      'price': 20.0,
      'cost': 10.0,
      'quantity': 100.0,
      'isArchived': false,
      'isManufacturedOnDemand': false,
    });

    final source = await _createAdjustment(
      db: db,
      repo: repo,
      merchantId: merchantId,
      productId: productId,
      from: 100,
      to: 110,
      reason: 'QA +10 adjustment',
    );

    expect((await db.collection('products').doc(productId).get()).data()?['quantity'], 110.0);
    await repo.revertLog(source, userEmail: 'qa@test.local', userName: 'QA');

    final productAfter = await db.collection('products').doc(productId).get();
    expect((productAfter.data()?['quantity'] as num).toDouble(), 100.0);

    final sourceAfter = await db.collection('merchants').doc(merchantId).collection('inventory_logs').doc(source.id).get();
    expect(sourceAfter.data()?['isReverted'], true);

    final logsAfter = await db.collection('merchants').doc(merchantId).collection('inventory_logs')
        .where('productId', isEqualTo: productId).get();
    expect(logsAfter.docs.length, 2, reason: 'Undo must leave source + one reversing log');
    final reversing = logsAfter.docs.firstWhere((d) => d.id != source.id).data();
    expect((reversing['changeQuantity'] as num).toDouble(), -10.0);
    expect((reversing['newQuantity'] as num).toDouble(), 100.0);

    await repo.revertLog(source, userEmail: 'qa@test.local', userName: 'QA');
    final productAgain = await db.collection('products').doc(productId).get();
    expect((productAgain.data()?['quantity'] as num).toDouble(), 100.0);
    final logsAgain = await db.collection('merchants').doc(merchantId).collection('inventory_logs')
        .where('productId', isEqualTo: productId).get();
    expect(logsAgain.docs.length, 2);
  });

  testWidgets('TEST 17/34 - concurrent sale + stock adjustment + undo preserves final stock', (tester) async {
    final merchantId = await _login();
    final db = FirebaseFirestore.instance;
    final logRepo = InventoryLogRepository(db, merchantId);
    final orderRepo = OrderRepository(db);
    const productId = 'qa_inventory_concurrent_product';

    await db.collection('products').doc(productId).set({
      'id': productId,
      'merchantId': merchantId,
      'name': 'QA Inventory Product',
      'price': 20.0,
      'cost': 10.0,
      'quantity': 100.0,
      'isArchived': false,
      'isManufacturedOnDemand': false,
    });

    final source = await _createAdjustment(
      db: db,
      repo: logRepo,
      merchantId: merchantId,
      productId: productId,
      from: 100,
      to: 110,
      reason: 'QA base +10 before concurrency',
    );

    final sale = AppOrder(
      id: 'qa_inventory_concurrent_sale',
      merchantId: merchantId,
      creatorId: merchantId,
      creatorName: 'QA',
      createdAt: DateTime.now(),
      paymentMethod: 'cash',
      total: 20.0,
      paidAmount: 20.0,
      isCredit: false,
      customerId: 'default',
      customerName: 'Default',
      items: const [
        CartItem(
          productId: productId,
          productName: 'QA Inventory Product',
          quantity: 1,
          price: 20.0,
          total: 20.0,
          costPrice: 10.0,
        ),
      ],
      status: 'completed',
    );

    Future<void> manualPlusFive() async {
      await db.collection('products').doc(productId).update({
        'quantity': FieldValue.increment(5),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await logRepo.logChange(
        productId: productId,
        productName: 'QA Inventory Product',
        previousQuantity: 110,
        newQuantity: 115,
        reason: 'QA concurrent +5',
        userEmail: 'qa@test.local',
        userName: 'QA',
        itemType: 'product',
      );
    }

    await Future.wait([
      orderRepo.createOrder(sale),
      manualPlusFive(),
      logRepo.revertLog(source, userEmail: 'qa@test.local', userName: 'QA'),
    ]);

    final product = await db.collection('products').doc(productId).get();
    expect((product.data()?['quantity'] as num).toDouble(), 104.0,
        reason: 'Concurrent atomic effects must converge to 104 exactly');

    final order = await db.collection('orders').doc('qa_inventory_concurrent_sale').get();
    expect(order.exists, true);
    final sourceAfter = await db.collection('merchants').doc(merchantId).collection('inventory_logs').doc(source.id).get();
    expect(sourceAfter.data()?['isReverted'], true);
  });
}

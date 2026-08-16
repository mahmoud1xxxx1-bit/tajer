import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:tajer/features/orders/data/order_repository.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/customers/data/customer_repository.dart';
import 'package:tajer/features/customers/domain/customer.dart';

Future<String> _login() async {
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  } catch (_) {}
  final auth = FirebaseAuth.instance;
  try {
    await auth.signInWithEmailAndPassword(email: 'qa-customer@test.local', password: 'password123');
  } catch (_) {
    try {
      await auth.createUserWithEmailAndPassword(email: 'qa-customer@test.local', password: 'password123');
    } catch (_) {
      await auth.signInWithEmailAndPassword(email: 'qa-customer@test.local', password: 'password123');
    }
  }
  return auth.currentUser!.uid;
}

Future<void> _deleteQuery(Query<Map<String, dynamic>> q) async {
  final s = await q.get();
  for (final d in s.docs) { await d.reference.delete(); }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 2/34 - credit sale and partial customer debt collection', (tester) async {
    final db = FirebaseFirestore.instance;
    final merchantId = await _login();
    final orderRepo = OrderRepository(db);
    final customerRepo = CustomerRepository(db);

    await _deleteQuery(db.collection('orders').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('customers').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('merchants').doc(merchantId).collection('payments'));
    await _deleteQuery(db.collection('shifts').where('merchantId', isEqualTo: merchantId));

    const customerId = 'qa_credit_customer';
    const productId = 'qa_credit_product';
    const shiftId = 'qa_credit_shift';
    const orderId = 'qa_credit_order';

    await customerRepo.addCustomer(Customer(
      id: customerId,
      merchantId: merchantId,
      name: 'QA Credit Customer',
      phone: '0500000000',
      createdAt: DateTime.now(),
    ));
    await db.collection('products').doc(productId).set({
      'id': productId,
      'merchantId': merchantId,
      'name': 'QA Credit Product',
      'price': 200.0,
      'cost': 50.0,
      'quantity': 20.0,
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
      'startCash': 100.0,
      'status': 'open',
      'cashSales': 0.0,
      'debtCollectionsCash': 0.0,
      'debtCollectionsCard': 0.0,
      'debtCollectionsTransfer': 0.0,
    });

    final order = AppOrder(
      id: orderId,
      merchantId: merchantId,
      creatorId: merchantId,
      creatorName: 'QA',
      createdAt: DateTime.now(),
      paymentMethod: 'cash',
      total: 200.0,
      paidAmount: 50.0,
      isCredit: true,
      customerId: customerId,
      customerName: 'QA Credit Customer',
      items: const [CartItem(
        productId: productId,
        productName: 'QA Credit Product',
        quantity: 1,
        price: 200.0,
        total: 200.0,
        costPrice: 50.0,
      )],
      status: 'completed',
    );

    await orderRepo.createOrder(order, shiftId: shiftId);

    var customer = await db.collection('customers').doc(customerId).get();
    expect((customer.data()?['totalDebt'] as num).toDouble(), 150.0,
        reason: 'Credit sale 200 with 50 initial payment must add 150 debt');

    await orderRepo.payCustomerDebt(
      merchantId: merchantId,
      customerId: customerId,
      amountPaid: 40,
      shiftId: shiftId,
      paymentMethod: 'cash',
    );

    customer = await db.collection('customers').doc(customerId).get();
    final orderAfter = await db.collection('orders').doc(orderId).get();
    final shiftAfter = await db.collection('shifts').doc(shiftId).get();
    final payments = await db.collection('merchants').doc(merchantId).collection('payments')
        .where('customerId', isEqualTo: customerId).get();

    expect((customer.data()?['totalDebt'] as num).toDouble(), 110.0);
    expect((orderAfter.data()?['paidAmount'] as num).toDouble(), 90.0,
        reason: '50 initial + 40 collection = 90 paid on invoice');
    expect((shiftAfter.data()?['debtCollectionsCash'] as num).toDouble(), 40.0);
    expect(payments.docs.length, 1);
    expect((payments.docs.first.data()['amount'] as num).toDouble(), 40.0);
    expect(payments.docs.first.data()['paymentMethod'], 'cash');
  });

  testWidgets('TEST 15/34 - 10 concurrent debt payments never make debt negative', (tester) async {
    final db = FirebaseFirestore.instance;
    final merchantId = await _login();
    final orderRepo = OrderRepository(db);

    await _deleteQuery(db.collection('orders').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('customers').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('merchants').doc(merchantId).collection('payments'));
    await _deleteQuery(db.collection('shifts').where('merchantId', isEqualTo: merchantId));

    const customerId = 'qa_concurrent_customer';
    const orderId = 'qa_concurrent_credit_order';
    const shiftId = 'qa_concurrent_shift';

    await db.collection('customers').doc(customerId).set({
      'id': customerId,
      'merchantId': merchantId,
      'name': 'QA Concurrent Customer',
      'phone': '',
      'totalPurchases': 100.0,
      'orderCount': 1,
      'totalDebt': 100.0,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
    await db.collection('orders').doc(orderId).set({
      'id': orderId,
      'merchantId': merchantId,
      'creatorId': merchantId,
      'creatorName': 'QA',
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'paymentMethod': 'credit',
      'total': 100.0,
      'paidAmount': 0.0,
      'initialPaidAmount': 0.0,
      'isCredit': true,
      'customerId': customerId,
      'customerName': 'QA Concurrent Customer',
      'items': <dynamic>[],
      'status': 'completed',
    });
    await db.collection('shifts').doc(shiftId).set({
      'id': shiftId,
      'merchantId': merchantId,
      'status': 'open',
      'debtCollectionsCash': 0.0,
      'debtCollectionsCard': 0.0,
      'debtCollectionsTransfer': 0.0,
    });

    final futures = List.generate(10, (i) => orderRepo.payCustomerDebt(
      merchantId: merchantId,
      customerId: customerId,
      amountPaid: 10,
      shiftId: shiftId,
      paymentMethod: 'cash',
    ));
    await Future.wait(futures);

    final customer = await db.collection('customers').doc(customerId).get();
    final order = await db.collection('orders').doc(orderId).get();
    final shift = await db.collection('shifts').doc(shiftId).get();
    final payments = await db.collection('merchants').doc(merchantId).collection('payments')
        .where('customerId', isEqualTo: customerId).get();

    expect((customer.data()?['totalDebt'] as num).toDouble(), 0.0,
        reason: '10 concurrent x10 must settle exactly 100 and never go below zero');
    expect((order.data()?['paidAmount'] as num).toDouble(), 100.0);
    expect((shift.data()?['debtCollectionsCash'] as num).toDouble(), 100.0);
    expect(payments.docs.length, 10);
    expect(payments.docs.fold<double>(0, (s, d) => s + (d.data()['amount'] as num).toDouble()), 100.0);
  });
}

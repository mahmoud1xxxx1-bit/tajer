import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:tajer/features/orders/data/order_repository.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/shifts/data/shift_repository.dart';
import 'package:tajer/features/shifts/domain/shift.dart';
import 'package:tajer/features/expenses/data/expense_repository.dart';
import 'package:tajer/features/expenses/domain/expense.dart';

Future<String> _login() async {
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  } catch (_) {}
  final auth = FirebaseAuth.instance;
  try {
    await auth.signInWithEmailAndPassword(email: 'qa-shift@test.local', password: 'password123');
  } catch (_) {
    try {
      await auth.createUserWithEmailAndPassword(email: 'qa-shift@test.local', password: 'password123');
    } catch (_) {
      await auth.signInWithEmailAndPassword(email: 'qa-shift@test.local', password: 'password123');
    }
  }
  return auth.currentUser!.uid;
}

Future<void> _deleteQuery(Query<Map<String, dynamic>> q) async {
  final s = await q.get();
  for (final d in s.docs) { await d.reference.delete(); }
}

AppOrder _order(String id, String merchantId, String productId, String method, double total) => AppOrder(
  id: id,
  merchantId: merchantId,
  creatorId: merchantId,
  creatorName: 'QA',
  createdAt: DateTime.now(),
  paymentMethod: method,
  total: total,
  paidAmount: total,
  isCredit: false,
  customerId: 'walk_in',
  customerName: 'Walk-in',
  items: [CartItem(productId: productId, productName: 'Shift Product', quantity: 1, price: total, total: total, costPrice: 5)],
  status: 'completed',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 4/34 - full shift cycle and expected cash formula', (tester) async {
    final db = FirebaseFirestore.instance;
    final merchantId = await _login();
    final orderRepo = OrderRepository(db);
    final shiftRepo = ShiftRepository(db);
    final expenseRepo = ExpenseRepository(db, merchantId);

    await _deleteQuery(db.collection('orders').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('shifts').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('customers').where('merchantId', isEqualTo: merchantId));
    await _deleteQuery(db.collection('merchants').doc(merchantId).collection('payments'));
    await _deleteQuery(db.collection('merchants').doc(merchantId).collection('expenses'));

    const shiftId = 'qa_full_shift';
    const productId = 'qa_shift_product';
    final started = DateTime.now().subtract(const Duration(minutes: 1));
    await shiftRepo.openShift(Shift(
      id: shiftId,
      merchantId: merchantId,
      employeeId: merchantId,
      employeeName: 'QA',
      startTime: started,
      startCash: 100,
      cashSales: 0,
      cardTotal: 0,
      transferTotal: 0,
      debtCollectionsCash: 0,
      debtCollectionsCard: 0,
      debtCollectionsTransfer: 0,
      refundsCash: 0,
      refundsCard: 0,
      refundsTransfer: 0,
      totalTax: 0,
      status: 'open',
    ));
    await db.collection('products').doc(productId).set({
      'id': productId, 'merchantId': merchantId, 'name': 'Shift Product',
      'price': 200.0, 'cost': 5.0, 'quantity': 100.0,
      'isArchived': false, 'isManufacturedOnDemand': false, 'recipe': <dynamic>[],
    });

    final cashOrder = _order('qa_shift_cash', merchantId, productId, 'cash', 200);
    final cardOrder = _order('qa_shift_card', merchantId, productId, 'card', 100);
    final transferOrder = _order('qa_shift_transfer', merchantId, productId, 'transfer', 50);
    await orderRepo.createOrder(cashOrder, shiftId: shiftId);
    await orderRepo.createOrder(cardOrder, shiftId: shiftId);
    await orderRepo.createOrder(transferOrder, shiftId: shiftId);

    // Seed an already-existing customer debt and invoice, then collect 30 cash through Tajer's payment transaction.
    await db.collection('customers').doc('qa_shift_customer').set({
      'id': 'qa_shift_customer', 'merchantId': merchantId, 'name': 'Shift Customer', 'phone': '',
      'totalPurchases': 60.0, 'orderCount': 1, 'totalDebt': 60.0,
      'createdAt': FieldValue.serverTimestamp(), 'isActive': true,
    });
    await db.collection('orders').doc('qa_shift_credit').set({
      'id': 'qa_shift_credit', 'merchantId': merchantId, 'creatorId': merchantId, 'creatorName': 'QA',
      'createdAt': Timestamp.fromDate(DateTime.now()), 'paymentMethod': 'credit',
      'total': 60.0, 'paidAmount': 0.0, 'initialPaidAmount': 0.0, 'isCredit': true,
      'customerId': 'qa_shift_customer', 'customerName': 'Shift Customer', 'items': <dynamic>[], 'status': 'completed',
    });
    await orderRepo.payCustomerDebt(
      merchantId: merchantId, customerId: 'qa_shift_customer', amountPaid: 30,
      shiftId: shiftId, paymentMethod: 'cash',
    );

    final now = DateTime.now();
    await expenseRepo.addExpense(Expense(
      id: 'qa_op_cash', merchantId: merchantId, title: 'Operating Cash', amount: 20,
      category: 'General', paymentMethod: 'cash', isFromShiftDrawer: true,
      isSupplierPayment: false, date: now, createdAt: now,
    ));
    await expenseRepo.addExpense(Expense(
      id: 'qa_supplier_cash', merchantId: merchantId, title: 'Supplier Cash', amount: 10,
      category: 'Supplier Payment', paymentMethod: 'cash', isFromShiftDrawer: true,
      isSupplierPayment: true, date: now, createdAt: now,
    ));
    await expenseRepo.addExpense(Expense(
      id: 'qa_op_network', merchantId: merchantId, title: 'Operating Network', amount: 15,
      category: 'General', paymentMethod: 'network', isFromShiftDrawer: false,
      isSupplierPayment: false, date: now, createdAt: now,
    ));

    // Cancel the cash sale; #608 records this as refundsCash rather than mutating historical cashSales.
    await orderRepo.updateOrderStatus(cashOrder, 'cancelled');

    final shiftDoc = await db.collection('shifts').doc(shiftId).get();
    final current = Shift.fromJson(shiftDoc.data()!);
    final expenses = await db.collection('merchants').doc(merchantId).collection('expenses').get();
    final opCash = expenses.docs.where((d) {
      final x=d.data(); return x['isSupplierPayment'] != true && x['paymentMethod']=='cash' && x['isFromShiftDrawer']==true && x['isCancelled']!=true;
    }).fold<double>(0, (s,d)=>s+(d.data()['amount'] as num).toDouble());
    final supplierCash = expenses.docs.where((d) {
      final x=d.data(); return x['isSupplierPayment']==true && x['paymentMethod']=='cash' && x['isFromShiftDrawer']==true && x['isCancelled']!=true;
    }).fold<double>(0, (s,d)=>s+(d.data()['amount'] as num).toDouble());

    final expectedCash = current.startCash + (current.cashSales ?? 0) +
        (current.debtCollectionsCash ?? 0) - opCash - supplierCash - (current.refundsCash ?? 0);
    expect(expectedCash, 100.0,
        reason: '100 start +200 cash sales +30 debt cash -20 op -10 supplier -200 refund = 100');
    expect((current.cardTotal ?? 0), 100.0);
    expect((current.transferTotal ?? 0), 50.0);

    const actualCash = 95.0;
    final closed = current.copyWith(
      endTime: DateTime.now(), expectedCash: expectedCash, actualCash: actualCash,
      actualCard: 100, actualTransfer: 50, status: 'closed',
    );
    await shiftRepo.closeShift(closed);

    final finalDoc = await db.collection('shifts').doc(shiftId).get();
    expect(finalDoc.data()?['status'], 'closed');
    expect((finalDoc.data()?['expectedCash'] as num).toDouble(), 100.0);
    expect((finalDoc.data()?['actualCash'] as num).toDouble(), 95.0);
    expect(actualCash - expectedCash, -5.0, reason: 'Shift shortage/overage must be -5');
    expect((finalDoc.data()?['refundsCash'] as num).toDouble(), 200.0);
    expect((finalDoc.data()?['debtCollectionsCash'] as num).toDouble(), 30.0);
  });
}

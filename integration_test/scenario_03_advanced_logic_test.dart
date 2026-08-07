import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import 'package:tajer/features/orders/data/order_repository.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/shifts/data/shift_repository.dart';
import 'package:tajer/features/shifts/domain/shift.dart';
import 'package:tajer/features/expenses/data/expense_repository.dart';
import 'package:tajer/features/expenses/domain/expense.dart';
import 'package:tajer/features/customers/data/customer_repository.dart';
import 'package:tajer/features/customers/domain/customer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 3: Advanced Accounting Scenarios (1-7)', (tester) async {
    try {
      await Firebase.initializeApp();
      FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
      await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    } catch (e) {
      print('Firebase init skipped');
    }

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await Future.delayed(const Duration(seconds: 2));

    try {
      await auth.signInWithEmailAndPassword(email: 'test@admin.com', password: 'password123');
    } catch(e) {}
    
    expect(auth.currentUser, isNotNull);
    final uid = auth.currentUser!.uid;

    final orderRepo = OrderRepository(firestore);
    final shiftRepo = ShiftRepository(firestore);
    final customerRepo = CustomerRepository(firestore);

    final oldOrders = await firestore.collection('orders').where('merchantId', isEqualTo: uid).get();
    for (var doc in oldOrders.docs) { await doc.reference.delete(); }
    final oldShifts = await firestore.collection('shifts').where('merchantId', isEqualTo: uid).get();
    for (var doc in oldShifts.docs) { await doc.reference.delete(); }

    final shiftId = const Uuid().v4();
    final shift = Shift(
      id: shiftId,
      merchantId: uid,
      employeeId: uid,
      employeeName: 'Admin',
      startTime: DateTime.now(),
      startCash: 100.0,
      status: 'open',
    );
    await shiftRepo.openShift(shift);

    Future<Shift> getShift() async {
      final snap = await firestore.collection('shifts').doc(shiftId).get();
      return Shift.fromJson(snap.data()!);
    }

    // 1. Transfer Sale
    final orderT = AppOrder(
      id: 'ord_trans', merchantId: uid, creatorId: uid, creatorName: 'Admin',
      createdAt: DateTime.now(), paymentMethod: 'transfer', total: 60.0, paidAmount: 60.0,
      isCredit: false, customerId: 'default', customerName: 'Default',
      items: [const CartItem(productId: 'p1', productName: 'p1', quantity: 1, price: 60.0, total: 60.0, costPrice: 10.0)],
      status: 'completed',
    );
    await orderRepo.createOrder(orderT, shiftId: shiftId);
    expect((await getShift()).transferTotal, 60.0, reason: "Transfer sale should add to transferTotal");

    // 2. Void Cash Sale
    final orderCash = AppOrder(
      id: 'ord_cash', merchantId: uid, creatorId: uid, creatorName: 'Admin',
      createdAt: DateTime.now(), paymentMethod: 'cash', total: 40.0, paidAmount: 40.0,
      isCredit: false, customerId: 'default', customerName: 'Default',
      items: [const CartItem(productId: 'p1', productName: 'p1', quantity: 1, price: 40.0, total: 40.0, costPrice: 10.0)],
      status: 'completed',
    );
    await orderRepo.createOrder(orderCash, shiftId: shiftId);
    await orderRepo.deleteOrder(orderCash);
    expect((await getShift()).refundsCash, 40.0, reason: "Voiding cash sale should add to refundsCash");

    // 3. Void Split Sale
    final orderSplit = AppOrder(
      id: 'ord_split', merchantId: uid, creatorId: uid, creatorName: 'Admin',
      createdAt: DateTime.now(), paymentMethod: 'split', splitCashAmount: 20.0, splitNetworkAmount: 30.0,
      total: 50.0, paidAmount: 50.0, isCredit: false, customerId: 'default', customerName: 'Default',
      items: [const CartItem(productId: 'p1', productName: 'p1', quantity: 1, price: 50.0, total: 50.0, costPrice: 10.0)],
      status: 'completed',
    );
    await orderRepo.createOrder(orderSplit, shiftId: shiftId);
    await orderRepo.deleteOrder(orderSplit);
    var sh = await getShift();
    expect(sh.refundsCash, 60.0, reason: "Void split cash (40+20=60)");
    expect(sh.refundsCard, 30.0, reason: "Void split card (30)");

    // 4 & 5. End Shift Shortage / Overage
    final shiftEnd = (await getShift()).copyWith(endTime: DateTime.now(), expectedCash: 100.0, actualCash: 80.0); // Shortage
    await shiftRepo.closeShift(shiftEnd);
    expect((await getShift()).actualCash, 80.0, reason: "Shortage of 20 should be recorded in actualCash");

    print("TEST 3 Advanced Completed");
  });
}

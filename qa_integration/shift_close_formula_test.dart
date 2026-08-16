import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tajer/firebase_options.dart';

import 'package:tajer/features/shifts/data/shift_repository.dart';
import 'package:tajer/features/shifts/domain/shift.dart';
import 'package:tajer/features/expenses/domain/expense.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 4/34 - full shift close expected cash formula', (tester) async {
    final merchantId = await _login();
    final db = FirebaseFirestore.instance;
    final repo = ShiftRepository(db);

    final oldShifts = await db.collection('shifts').where('merchantId', isEqualTo: merchantId).get();
    for (final d in oldShifts.docs) { await d.reference.delete(); }
    final expenseRef = db.collection('merchants').doc(merchantId).collection('expenses');
    final oldExpenses = await expenseRef.get();
    for (final d in oldExpenses.docs) { await d.reference.delete(); }

    const shiftId = 'qa_shift_formula';
    final start = DateTime.now().subtract(const Duration(minutes: 5));
    final shift = Shift(
      id: shiftId,
      merchantId: merchantId,
      employeeId: merchantId,
      employeeName: 'QA',
      startTime: start,
      startCash: 500,
      cashSales: 300,
      debtCollectionsCash: 100,
      refundsCash: 20,
      status: 'open',
    );
    await repo.openShift(shift);

    final operating = Expense(
      id: 'qa_op_exp',
      merchantId: merchantId,
      title: 'Operating cash',
      amount: 50,
      paymentMethod: 'cash',
      isFromShiftDrawer: true,
      isSupplierPayment: false,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      shiftId: shiftId,
    );
    final supplier = Expense(
      id: 'qa_supplier_exp',
      merchantId: merchantId,
      title: 'Supplier cash',
      amount: 80,
      paymentMethod: 'cash',
      isFromShiftDrawer: true,
      isSupplierPayment: true,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      shiftId: shiftId,
    );
    final outsideDrawer = Expense(
      id: 'qa_outside_exp',
      merchantId: merchantId,
      title: 'Outside drawer',
      amount: 999,
      paymentMethod: 'cash',
      isFromShiftDrawer: false,
      isSupplierPayment: true,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      shiftId: shiftId,
    );
    await expenseRef.doc(operating.id).set(operating.toJson());
    await expenseRef.doc(supplier.id).set(supplier.toJson());
    await expenseRef.doc(outsideDrawer.id).set(outsideDrawer.toJson());

    final expenses = (await expenseRef.get()).docs.map((d) => Expense.fromJson(d.data())).toList();
    final allShiftExpenses = expenses.where((e) => e.date.isAfter(start));
    final operatingCash = allShiftExpenses
        .where((e) => !e.isSupplierPayment && e.paymentMethod == 'cash' && e.isFromShiftDrawer && !e.isCancelled)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final supplierCash = allShiftExpenses
        .where((e) => e.isSupplierPayment && e.paymentMethod == 'cash' && e.isFromShiftDrawer && !e.isCancelled)
        .fold<double>(0, (sum, e) => sum + e.amount);

    final expectedCash = shift.startCash + (shift.cashSales ?? 0) +
        (shift.debtCollectionsCash ?? 0) - operatingCash - supplierCash -
        (shift.refundsCash ?? 0);

    expect(operatingCash, 50.0);
    expect(supplierCash, 80.0, reason: 'Outside-drawer supplier payment must not reduce drawer');
    expect(expectedCash, 750.0,
        reason: '500 + 300 + 100 - 50 - 80 - 20 = 750');

    final closing = shift.copyWith(
      endTime: DateTime.now(),
      expectedCash: expectedCash,
      actualCash: 750,
      actualCard: 0,
      actualTransfer: 0,
      status: 'closed',
    );
    await repo.closeShift(closing);

    final closedDoc = await db.collection('shifts').doc(shiftId).get();
    final closed = Shift.fromJson(closedDoc.data()!);
    expect(closed.status, 'closed');
    expect(closed.expectedCash, 750.0);
    expect(closed.actualCash, 750.0);
  });
}

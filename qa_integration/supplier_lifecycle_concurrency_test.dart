import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:tajer/features/suppliers/data/supplier_repository.dart';
import 'package:tajer/features/suppliers/domain/supplier.dart';
import 'package:tajer/features/suppliers/domain/supplier_transaction.dart';
import 'package:tajer/features/expenses/domain/expense.dart';

Future<String> _login() async {
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  } catch (_) {}
  final auth = FirebaseAuth.instance;
  try {
    await auth.signInWithEmailAndPassword(email: 'qa-supplier@test.local', password: 'password123');
  } catch (_) {
    try {
      await auth.createUserWithEmailAndPassword(email: 'qa-supplier@test.local', password: 'password123');
    } catch (_) {
      await auth.signInWithEmailAndPassword(email: 'qa-supplier@test.local', password: 'password123');
    }
  }
  return auth.currentUser!.uid;
}

Future<void> _clearSupplierSpace(FirebaseFirestore db, String merchantId) async {
  final supplierRoot = db.collection('merchants').doc(merchantId).collection('suppliers');
  final suppliers = await supplierRoot.get();
  for (final supplier in suppliers.docs) {
    final txs = await supplier.reference.collection('transactions').get();
    for (final tx in txs.docs) {
      await tx.reference.delete();
    }
    await supplier.reference.delete();
  }
  final expenses = await db.collection('merchants').doc(merchantId).collection('expenses').get();
  for (final expense in expenses.docs) {
    await expense.reference.delete();
  }
}

SupplierTransaction _tx({
  required String id,
  required String supplierId,
  required String merchantId,
  required double amount,
  required String method,
}) {
  final now = DateTime.now();
  return SupplierTransaction(
    id: id,
    supplierId: supplierId,
    merchantId: merchantId,
    amount: amount,
    type: 'payment',
    paymentMethod: method,
    description: 'QA payment $id',
    date: now,
    createdAt: now,
  );
}

Expense _expense({
  required String id,
  required String merchantId,
  required double amount,
  required String method,
  required bool fromDrawer,
}) {
  final now = DateTime.now();
  return Expense(
    id: id,
    merchantId: merchantId,
    title: 'Supplier QA Payment',
    amount: amount,
    category: 'Supplier Payment',
    notes: 'QA',
    isSupplierPayment: true,
    paymentMethod: method,
    date: now,
    createdAt: now,
    isFromShiftDrawer: fromDrawer,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 5/34 - supplier full lifecycle is atomic and correctly classified', (tester) async {
    final db = FirebaseFirestore.instance;
    final merchantId = await _login();
    await _clearSupplierSpace(db, merchantId);
    final repo = SupplierRepository(db, merchantId);

    const supplierId = 'qa_supplier_lifecycle';
    await repo.addSupplier(Supplier(
      id: supplierId,
      merchantId: merchantId,
      name: 'QA Supplier',
      totalDebt: 1000,
      createdAt: DateTime.now(),
    ));

    Future<double> debt() async {
      final s = await db.collection('merchants').doc(merchantId).collection('suppliers').doc(supplierId).get();
      return (s.data()?['totalDebt'] as num).toDouble();
    }

    final drawerTx = _tx(id: 'pay_drawer', supplierId: supplierId, merchantId: merchantId, amount: 200, method: 'cash');
    await repo.recordSupplierPayment(
      supplierTransaction: drawerTx,
      expense: _expense(id: 'exp_drawer', merchantId: merchantId, amount: 200, method: 'cash', fromDrawer: true),
    );
    expect(await debt(), 800.0);

    final outsideTx = _tx(id: 'pay_outside', supplierId: supplierId, merchantId: merchantId, amount: 100, method: 'cash');
    await repo.recordSupplierPayment(
      supplierTransaction: outsideTx,
      expense: _expense(id: 'exp_outside', merchantId: merchantId, amount: 100, method: 'cash', fromDrawer: false),
    );
    expect(await debt(), 700.0);

    final networkTx = _tx(id: 'pay_network', supplierId: supplierId, merchantId: merchantId, amount: 50, method: 'network');
    await repo.recordSupplierPayment(
      supplierTransaction: networkTx,
      expense: _expense(id: 'exp_network', merchantId: merchantId, amount: 50, method: 'network', fromDrawer: false),
    );
    expect(await debt(), 650.0);

    final networkTxDoc = await db.collection('merchants').doc(merchantId).collection('suppliers').doc(supplierId).collection('transactions').doc('pay_network').get();
    final networkExpDoc = await db.collection('merchants').doc(merchantId).collection('expenses').doc('exp_network').get();
    expect(networkTxDoc.exists, true);
    expect(networkExpDoc.exists, true);
    expect(networkExpDoc.data()?['isSupplierPayment'], true, reason: 'Supplier payment must remain classified separately from operating expenses');
    expect(networkExpDoc.data()?['isFromShiftDrawer'], false);
    expect(networkExpDoc.data()?['paymentMethod'], 'network');

    await repo.cancelSupplierTransaction(supplierTransaction: networkTx, linkedExpenseId: 'exp_network');
    expect(await debt(), 700.0, reason: 'Cancelling a 50 payment must restore exactly 50 debt');
    final cancelledTx = await db.collection('merchants').doc(merchantId).collection('suppliers').doc(supplierId).collection('transactions').doc('pay_network').get();
    final cancelledExp = await db.collection('merchants').doc(merchantId).collection('expenses').doc('exp_network').get();
    expect(cancelledTx.data()?['isCancelled'], true);
    expect(cancelledExp.data()?['isCancelled'], true);
  });

  testWidgets('TEST 16/34 - concurrent supplier payments preserve final debt and ledger counts', (tester) async {
    final db = FirebaseFirestore.instance;
    final merchantId = await _login();
    await _clearSupplierSpace(db, merchantId);
    final repo = SupplierRepository(db, merchantId);

    const supplierId = 'qa_supplier_concurrent';
    await repo.addSupplier(Supplier(
      id: supplierId,
      merchantId: merchantId,
      name: 'QA Concurrent Supplier',
      totalDebt: 1000,
      createdAt: DateTime.now(),
    ));

    final futures = <Future<void>>[];
    for (var i = 0; i < 10; i++) {
      final tx = _tx(id: 'ctx_$i', supplierId: supplierId, merchantId: merchantId, amount: 10, method: i.isEven ? 'cash' : 'network');
      final exp = _expense(id: 'cexp_$i', merchantId: merchantId, amount: 10, method: i.isEven ? 'cash' : 'network', fromDrawer: i.isEven);
      futures.add(repo.recordSupplierPayment(supplierTransaction: tx, expense: exp));
    }
    await Future.wait(futures);

    final supplierDoc = await db.collection('merchants').doc(merchantId).collection('suppliers').doc(supplierId).get();
    expect((supplierDoc.data()?['totalDebt'] as num).toDouble(), 900.0, reason: '10 concurrent payments x 10 must reduce debt from 1000 to 900 exactly');

    final txs = await db.collection('merchants').doc(merchantId).collection('suppliers').doc(supplierId).collection('transactions').get();
    expect(txs.docs.length, 10);

    final expenses = await db.collection('merchants').doc(merchantId).collection('expenses').get();
    final linked = expenses.docs.where((d) => d.id.startsWith('cexp_')).toList();
    expect(linked.length, 10);
    expect(linked.every((d) => d.data()['isSupplierPayment'] == true), true);
  });
}

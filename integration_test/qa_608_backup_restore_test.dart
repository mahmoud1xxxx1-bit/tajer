import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajer/firebase_options.dart';
import 'package:tajer/core/services/backup_service.dart';

bool _configured = false;

Future<String> _login() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (!_configured) {
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    _configured = true;
  }
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInWithEmailAndPassword(email: 'qa-backup@test.local', password: 'password123');
    } catch (_) {
      await auth.createUserWithEmailAndPassword(email: 'qa-backup@test.local', password: 'password123');
    }
  }
  final uid = auth.currentUser!.uid;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'id': uid,
    'role': 'merchant',
    'plan': 'premium',
    'email': 'qa-backup@test.local',
    'isAnonymous': false,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return uid;
}

Future<void> _deleteSeededWorkspace(FirebaseFirestore db, String m) async {
  const root = <String>['products', 'orders', 'customers', 'raw_materials', 'shifts'];
  for (final c in root) {
    final q = await db.collection(c).where('merchantId', isEqualTo: m).get();
    for (final d in q.docs) { await d.reference.delete(); }
  }
  const merchantSubs = <String>[
    'categories','expenses','inventory_logs','suppliers','payments',
    'notebook_books','notebook_accounts','notebook_categories','notebook_people','notebook_transactions'
  ];
  for (final c in merchantSubs) {
    final col = db.collection('merchants').doc(m).collection(c);
    if (c == 'suppliers') {
      for (final s in (await col.get()).docs) {
        for (final t in (await s.reference.collection('transactions').get()).docs) {
          await t.reference.delete();
        }
      }
    }
    for (final d in (await col.get()).docs) { await d.reference.delete(); }
  }
  for (final c in const ['employees', 'notifications']) {
    final col = db.collection('users').doc(m).collection(c);
    for (final d in (await col.get()).docs) { await d.reference.delete(); }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 9/34 - backup then restore diverse workspace preserving values and Timestamp types', (tester) async {
    final m = await _login();
    final db = FirebaseFirestore.instance;
    final backup = BackupService(db);
    final fixed = Timestamp.fromDate(DateTime.utc(2026, 8, 16, 10, 20, 30));

    await db.collection('products').doc('b_product').set({
      'id': 'b_product','merchantId': m,'name': 'Backup Product','price': 42.5,'quantity': 7,'createdAt': fixed,
    });
    await db.collection('orders').doc('b_order').set({
      'id':'b_order','merchantId':m,'customerId':'b_customer','customerName':'Backup Customer','total':42.5,
      'paidAmount':42.5,'isCredit':false,'status':'completed','paymentMethod':'cash','items':<dynamic>[], 'createdAt':fixed,
    });
    await db.collection('customers').doc('b_customer').set({
      'id':'b_customer','merchantId':m,'name':'Backup Customer','phone':'0500000000','totalDebt':0.0,
      'totalPurchases':42.5,'orderCount':1,'createdAt':fixed,'isActive':true,
    });
    await db.collection('shifts').doc('b_shift').set({
      'id':'b_shift','merchantId':m,'employeeId':m,'employeeName':'QA','startCash':100.0,'cashSales':42.5,
      'status':'open','startTime':fixed,
    });
    await db.collection('merchants').doc(m).collection('suppliers').doc('b_supplier').set({
      'id':'b_supplier','merchantId':m,'name':'Backup Supplier','totalDebt':300.0,'createdAt':fixed,
    });
    await db.collection('merchants').doc(m).collection('suppliers').doc('b_supplier').collection('transactions').doc('b_supplier_tx').set({
      'id':'b_supplier_tx','supplierId':'b_supplier','merchantId':m,'amount':50.0,'type':'payment',
      'paymentMethod':'cash','description':'backup supplier tx','date':fixed,'createdAt':fixed,'isCancelled':false,
    });
    await db.collection('merchants').doc(m).collection('expenses').doc('b_expense').set({
      'id':'b_expense','merchantId':m,'title':'Backup Expense','amount':25.0,'paymentMethod':'cash',
      'isSupplierPayment':false,'isFromShiftDrawer':true,'isCancelled':false,'date':fixed,'createdAt':fixed,
    });
    await db.collection('merchants').doc(m).collection('notebook_books').doc('b_book').set({
      'name':'Backup Book','createdAt':fixed,'isArchived':false,
    });
    await db.collection('merchants').doc(m).collection('notebook_accounts').doc('b_account').set({
      'name':'Cash','type':'cash','balance':900.0,'bookId':'b_book','createdAt':fixed,'isArchived':false,
    });
    await db.collection('merchants').doc(m).collection('notebook_people').doc('b_person').set({
      'name':'Backup Person','amountOwedToMe':120.0,'amountIOwe':0.0,'bookId':'b_book','createdAt':fixed,'isArchived':false,
    });
    await db.collection('merchants').doc(m).collection('notebook_transactions').doc('b_notebook_tx').set({
      'type':'income','amount':75.0,'bookId':'b_book','accountId':'b_account','date':fixed,'createdAt':fixed,
    });
    await db.collection('users').doc(m).collection('employees').doc('b_employee').set({
      'id':'b_employee','name':'Backup Employee','merchantId':m,'permissions':{'can_create_orders':true},'createdAt':fixed,
    });

    final jsonString = await backup.exportDataToJson(m);
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], 2);
    expect((decoded['products'] as List).length, 1);
    expect((decoded['orders'] as List).length, 1);
    expect((decoded['customers'] as List).length, 1);
    expect((decoded['shifts'] as List).length, 1);
    expect((decoded['suppliers'] as List).length, 1);
    expect((decoded['notebook_transactions'] as List).length, 1);
    final productBackup = Map<String, dynamic>.from((decoded['products'] as List).single as Map);
    expect((productBackup['createdAt'] as Map)['__tajer_type'], 'timestamp');

    await _deleteSeededWorkspace(db, m);
    expect((await db.collection('products').where('merchantId', isEqualTo: m).get()).docs, isEmpty);
    expect((await db.collection('merchants').doc(m).collection('suppliers').get()).docs, isEmpty);

    await backup.importDataFromJson(m, jsonString);

    final product = await db.collection('products').doc('b_product').get();
    final order = await db.collection('orders').doc('b_order').get();
    final customer = await db.collection('customers').doc('b_customer').get();
    final shift = await db.collection('shifts').doc('b_shift').get();
    final supplier = await db.collection('merchants').doc(m).collection('suppliers').doc('b_supplier').get();
    final supplierTx = await supplier.reference.collection('transactions').doc('b_supplier_tx').get();
    final expense = await db.collection('merchants').doc(m).collection('expenses').doc('b_expense').get();
    final book = await db.collection('merchants').doc(m).collection('notebook_books').doc('b_book').get();
    final account = await db.collection('merchants').doc(m).collection('notebook_accounts').doc('b_account').get();
    final person = await db.collection('merchants').doc(m).collection('notebook_people').doc('b_person').get();
    final ntx = await db.collection('merchants').doc(m).collection('notebook_transactions').doc('b_notebook_tx').get();
    final employee = await db.collection('users').doc(m).collection('employees').doc('b_employee').get();

    for (final snap in [product, order, customer, shift, supplier, supplierTx, expense, book, account, person, ntx, employee]) {
      expect(snap.exists, true);
    }
    expect(product.data()?['name'], 'Backup Product');
    expect((product.data()?['price'] as num).toDouble(), 42.5);
    expect(product.data()?['createdAt'], isA<Timestamp>());
    expect((product.data()?['createdAt'] as Timestamp).toDate().toUtc(), fixed.toDate().toUtc());
    expect((customer.data()?['totalPurchases'] as num).toDouble(), 42.5);
    expect((shift.data()?['cashSales'] as num).toDouble(), 42.5);
    expect((supplier.data()?['totalDebt'] as num).toDouble(), 300.0);
    expect((supplierTx.data()?['amount'] as num).toDouble(), 50.0);
    expect((account.data()?['balance'] as num).toDouble(), 900.0);
    expect((person.data()?['amountOwedToMe'] as num).toDouble(), 120.0);
    expect((ntx.data()?['amount'] as num).toDouble(), 75.0);
    expect((Map<String,dynamic>.from(employee.data()?['permissions'] as Map))['can_create_orders'], true);
  });
}

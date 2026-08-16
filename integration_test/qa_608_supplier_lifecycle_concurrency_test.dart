import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tajer/firebase_options.dart';
import 'package:tajer/features/suppliers/data/supplier_repository.dart';
import 'package:tajer/features/suppliers/domain/supplier.dart';
import 'package:tajer/features/suppliers/domain/supplier_transaction.dart';
import 'package:tajer/features/expenses/domain/expense.dart';

bool _emulatorsConfigured = false;
Future<String> _login() async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!_emulatorsConfigured) {
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    _emulatorsConfigured = true;
  }
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try { await auth.signInWithEmailAndPassword(email: 'qa-supplier@test.local', password: 'password123'); }
    catch (_) { try { await auth.createUserWithEmailAndPassword(email: 'qa-supplier@test.local', password: 'password123'); } catch (_) { await auth.signInWithEmailAndPassword(email: 'qa-supplier@test.local', password: 'password123'); } }
  }
  final uid = auth.currentUser!.uid;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'id': uid,
    'name': 'QA Supplier Merchant',
    'email': 'qa-supplier@test.local',
    'role': 'merchant',
    'plan': 'premium',
    'isAnonymous': false,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return uid;
}
SupplierTransaction _tx(String id,String sid,String mid,double amount,String method){final n=DateTime.now();return SupplierTransaction(id:id,supplierId:sid,merchantId:mid,amount:amount,type:'payment',paymentMethod:method,description:'QA $id',date:n,createdAt:n);}
Expense _exp(String id,String mid,double amount,String method,bool drawer){final n=DateTime.now();return Expense(id:id,merchantId:mid,title:'Supplier QA',amount:amount,category:'Supplier Payment',isSupplierPayment:true,paymentMethod:method,date:n,createdAt:n,isFromShiftDrawer:drawer);}

void main(){
 IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('TEST 5/34 - supplier full lifecycle is atomic and correctly classified',(tester) async {
  final mid=await _login(); final db=FirebaseFirestore.instance; final repo=SupplierRepository(db,mid); const sid='qa_supplier_lifecycle';
  await repo.addSupplier(Supplier(id:sid,merchantId:mid,name:'QA Supplier',totalDebt:1000,createdAt:DateTime.now()));
  Future<double> debt() async => ((await db.collection('merchants').doc(mid).collection('suppliers').doc(sid).get()).data()?['totalDebt'] as num).toDouble();
  final a=_tx('pay_drawer',sid,mid,200,'cash'); await repo.recordSupplierPayment(supplierTransaction:a,expense:_exp('exp_drawer',mid,200,'cash',true)); expect(await debt(),800.0);
  final b=_tx('pay_outside',sid,mid,100,'cash'); await repo.recordSupplierPayment(supplierTransaction:b,expense:_exp('exp_outside',mid,100,'cash',false)); expect(await debt(),700.0);
  final c=_tx('pay_network',sid,mid,50,'network'); await repo.recordSupplierPayment(supplierTransaction:c,expense:_exp('exp_network',mid,50,'network',false)); expect(await debt(),650.0);
  final ce=await db.collection('merchants').doc(mid).collection('expenses').doc('exp_network').get(); expect(ce.data()?['isSupplierPayment'],true); expect(ce.data()?['isFromShiftDrawer'],false); expect(ce.data()?['paymentMethod'],'network');
  await repo.cancelSupplierTransaction(supplierTransaction:c,linkedExpenseId:'exp_network'); expect(await debt(),700.0);
  expect((await db.collection('merchants').doc(mid).collection('suppliers').doc(sid).collection('transactions').doc('pay_network').get()).data()?['isCancelled'],true);
  expect((await db.collection('merchants').doc(mid).collection('expenses').doc('exp_network').get()).data()?['isCancelled'],true);
 });
 testWidgets('TEST 16/34 - concurrent supplier payments preserve final debt and ledger counts',(tester) async {
  final mid=await _login(); final db=FirebaseFirestore.instance; final repo=SupplierRepository(db,mid); const sid='qa_supplier_concurrent';
  await repo.addSupplier(Supplier(id:sid,merchantId:mid,name:'QA Concurrent Supplier',totalDebt:1000,createdAt:DateTime.now()));
  await Future.wait(List.generate(10,(i)=>repo.recordSupplierPayment(supplierTransaction:_tx('ctx_$i',sid,mid,10,i.isEven?'cash':'network'),expense:_exp('cexp_$i',mid,10,i.isEven?'cash':'network',i.isEven))));
  final s=await db.collection('merchants').doc(mid).collection('suppliers').doc(sid).get(); expect((s.data()?['totalDebt'] as num).toDouble(),900.0);
  expect((await db.collection('merchants').doc(mid).collection('suppliers').doc(sid).collection('transactions').get()).docs.length,10);
  final ex=(await db.collection('merchants').doc(mid).collection('expenses').get()).docs.where((d)=>d.id.startsWith('cexp_')).toList(); expect(ex.length,10); expect(ex.every((d)=>d.data()['isSupplierPayment']==true),true);
 });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tajer/firebase_options.dart';

import 'package:tajer/features/accounting_notebook/data/accounting_notebook_repository.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_provider.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_book.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_account.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_category.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_person.dart';

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
    await auth.signInWithEmailAndPassword(email: 'qa-notebook@test.local', password: 'password123');
  } catch (_) {
    try {
      await auth.createUserWithEmailAndPassword(email: 'qa-notebook@test.local', password: 'password123');
    } catch (_) {
      await auth.signInWithEmailAndPassword(email: 'qa-notebook@test.local', password: 'password123');
    }
  }
  return auth.currentUser!.uid;
}

Future<void> _clearCollection(CollectionReference<Map<String, dynamic>> ref) async {
  final snap = await ref.get();
  for (final d in snap.docs) { await d.reference.delete(); }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 7/34 - complete accounting notebook cycle', (tester) async {
    final merchantId = await _login();
    final db = FirebaseFirestore.instance;
    final repo = AccountingNotebookRepository(db, merchantId);
    final service = AccountingNotebookService(repo);

    await _clearCollection(repo.transactionsRef);
    await _clearCollection(repo.peopleRef);
    await _clearCollection(repo.categoriesRef);
    await _clearCollection(repo.accountsRef);
    await _clearCollection(repo.booksRef);

    final now = DateTime.now();
    const bookId = 'qa_book';
    const cashId = 'qa_cash';
    const bankId = 'qa_bank';
    const incomeCatId = 'qa_income_cat';
    const expenseCatId = 'qa_expense_cat';
    const personId = 'qa_person';

    await repo.createBook(NotebookBook(id: bookId, name: 'QA Book', createdAt: now));
    await repo.createAccount(NotebookAccount(id: cashId, name: 'Cash', type: 'cash', balance: 1000, bookId: bookId, createdAt: now));
    await repo.createAccount(NotebookAccount(id: bankId, name: 'Bank', type: 'bank', balance: 200, bookId: bookId, createdAt: now));
    await repo.createCategory(NotebookCategory(id: incomeCatId, name: 'Sales', type: 'income', bookId: bookId, createdAt: now));
    await repo.createCategory(NotebookCategory(id: expenseCatId, name: 'General', type: 'expense', bookId: bookId, createdAt: now));
    await repo.createPerson(NotebookPerson(id: personId, name: 'QA Person', amountOwedToMe: 0, amountIOwe: 0, bookId: bookId, createdAt: now));

    await service.createIncome(bookId: bookId, accountId: cashId, amount: 300, categoryId: incomeCatId, note: 'QA income');
    await service.createExpense(bookId: bookId, accountId: cashId, amount: 100, categoryId: expenseCatId, note: 'QA expense');
    await service.createDebt(bookId: bookId, personId: personId, amount: 400, isOwedToMe: true, note: 'QA receivable');
    await service.recordDebtPayment(bookId: bookId, personId: personId, accountId: cashId, amount: 150, isReceivablePayment: true, note: 'QA collect');
    await service.createDebt(bookId: bookId, personId: personId, amount: 200, isOwedToMe: false, note: 'QA payable');
    await service.recordDebtPayment(bookId: bookId, personId: personId, accountId: cashId, amount: 80, isReceivablePayment: false, note: 'QA pay');
    await service.transferFunds(bookId: bookId, fromAccountId: cashId, toAccountId: bankId, amount: 70, note: 'QA transfer');

    final cashDoc = await repo.accountsRef.doc(cashId).get();
    final bankDoc = await repo.accountsRef.doc(bankId).get();
    final personDoc = await repo.peopleRef.doc(personId).get();
    final txSnap = await repo.transactionsRef.where('bookId', isEqualTo: bookId).get();

    expect((cashDoc.data()?['balance'] as num).toDouble(), 1200.0,
        reason: '1000 +300 -100 +150 -80 -70 = 1200');
    expect((bankDoc.data()?['balance'] as num).toDouble(), 270.0,
        reason: '200 +70 transfer = 270');
    expect((personDoc.data()?['amountOwedToMe'] as num).toDouble(), 250.0,
        reason: '400 receivable -150 collection = 250');
    expect((personDoc.data()?['amountIOwe'] as num).toDouble(), 120.0,
        reason: '200 payable -80 payment = 120');
    expect(txSnap.docs.length, 7, reason: 'Every business event must have one notebook transaction');

    final types = txSnap.docs.map((d) => d.data()['type']).toList();
    for (final requiredType in [
      'income', 'expense', 'receivable', 'receivable_payment',
      'payable', 'payable_payment', 'account_transfer'
    ]) {
      expect(types.where((t) => t == requiredType).length, 1,
          reason: 'Expected exactly one $requiredType transaction');
    }

    final totalAccountBalance =
        (cashDoc.data()?['balance'] as num).toDouble() +
        (bankDoc.data()?['balance'] as num).toDouble();
    expect(totalAccountBalance, 1470.0,
        reason: 'Transfers must not change aggregate account balance');

    final peopleSnap = await repo.peopleRef.where('bookId', isEqualTo: bookId).get();
    final accountsSnap = await repo.accountsRef.where('bookId', isEqualTo: bookId).get();
    expect(peopleSnap.docs.length, 1);
    expect(accountsSnap.docs.length, 2);

    final incomeTotal = txSnap.docs
        .where((d) => d.data()['type'] == 'income')
        .fold<double>(0, (s, d) => s + (d.data()['amount'] as num).toDouble());
    final expenseTotal = txSnap.docs
        .where((d) => d.data()['type'] == 'expense')
        .fold<double>(0, (s, d) => s + (d.data()['amount'] as num).toDouble());
    expect(incomeTotal, 300.0);
    expect(expenseTotal, 100.0);
  });
}

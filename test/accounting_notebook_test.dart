import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_provider.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_repository.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_account.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_person.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_category.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late AccountingNotebookRepository repository;
  late AccountingNotebookService service;

  const merchantId = 'merchant_123';
  const bookId = 'book_1';
  const accountId1 = 'acc_1';
  const accountId2 = 'acc_2';
  const personId = 'person_1';
  const incomeCategoryId = 'cat_income';
  const expenseCategoryId = 'cat_expense';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    repository = AccountingNotebookRepository(fakeFirestore, merchantId);
    service = AccountingNotebookService(repository);

    final now = DateTime.now();
    await repository.accountsRef.doc(accountId1).set(
      NotebookAccount(
        id: accountId1,
        name: 'Cash',
        type: 'cash',
        balance: 1000.0,
        bookId: bookId,
        createdAt: now,
      ).toMap(),
    );

    await repository.accountsRef.doc(accountId2).set(
      NotebookAccount(
        id: accountId2,
        name: 'Bank',
        type: 'bank',
        balance: 5000.0,
        bookId: bookId,
        createdAt: now,
      ).toMap(),
    );

    await repository.peopleRef.doc(personId).set(
      NotebookPerson(
        id: personId,
        name: 'John Doe',
        amountOwedToMe: 0.0,
        amountIOwe: 0.0,
        bookId: bookId,
        createdAt: now,
      ).toMap(),
    );

    await repository.categoriesRef.doc(incomeCategoryId).set(
      NotebookCategory(
        id: incomeCategoryId,
        name: 'Income General',
        type: 'income',
        bookId: bookId,
        createdAt: now,
      ).toMap(),
    );

    await repository.categoriesRef.doc(expenseCategoryId).set(
      NotebookCategory(
        id: expenseCategoryId,
        name: 'Expense General',
        type: 'expense',
        bookId: bookId,
        createdAt: now,
      ).toMap(),
    );
  });

  group('AccountingNotebookService Tests', () {
    test('income increases selected notebook account', () async {
      await service.createIncome(
        bookId: bookId,
        accountId: accountId1,
        amount: 200.0,
        categoryId: incomeCategoryId,
      );

      final doc = await repository.accountsRef.doc(accountId1).get();
      final account = NotebookAccount.fromMap(doc.data()!, doc.id);
      expect(account.balance, 1200.0);
    });

    test('expense decreases selected notebook account', () async {
      await service.createExpense(
        bookId: bookId,
        accountId: accountId1,
        amount: 150.0,
        categoryId: expenseCategoryId,
      );

      final doc = await repository.accountsRef.doc(accountId1).get();
      final account = NotebookAccount.fromMap(doc.data()!, doc.id);
      expect(account.balance, 850.0);
    });

    test('receivable creation does NOT increase account balance', () async {
      await service.createDebt(
        bookId: bookId,
        personId: personId,
        amount: 300.0,
        isOwedToMe: true,
      );

      final docAcc = await repository.accountsRef.doc(accountId1).get();
      final account = NotebookAccount.fromMap(docAcc.data()!, docAcc.id);
      expect(account.balance, 1000.0);

      final docPerson = await repository.peopleRef.doc(personId).get();
      final person = NotebookPerson.fromMap(docPerson.data()!, docPerson.id);
      expect(person.amountOwedToMe, 300.0);
      expect(person.amountIOwe, 0.0);
    });

    test('payable creation does NOT decrease account balance', () async {
      await service.createDebt(
        bookId: bookId,
        personId: personId,
        amount: 400.0,
        isOwedToMe: false,
      );

      final docAcc = await repository.accountsRef.doc(accountId1).get();
      final account = NotebookAccount.fromMap(docAcc.data()!, docAcc.id);
      expect(account.balance, 1000.0);

      final docPerson = await repository.peopleRef.doc(personId).get();
      final person = NotebookPerson.fromMap(docPerson.data()!, docPerson.id);
      expect(person.amountOwedToMe, 0.0);
      expect(person.amountIOwe, 400.0);
    });

    test('receivable partial payment updates debt and increases account',
        () async {
      await service.createDebt(
        bookId: bookId,
        personId: personId,
        amount: 300.0,
        isOwedToMe: true,
      );

      await service.recordDebtPayment(
        bookId: bookId,
        personId: personId,
        accountId: accountId1,
        amount: 100.0,
        isReceivablePayment: true,
      );

      final docAcc = await repository.accountsRef.doc(accountId1).get();
      final account = NotebookAccount.fromMap(docAcc.data()!, docAcc.id);
      expect(account.balance, 1100.0);

      final docPerson = await repository.peopleRef.doc(personId).get();
      final person = NotebookPerson.fromMap(docPerson.data()!, docPerson.id);
      expect(person.amountOwedToMe, 200.0);
    });

    test('payable partial payment updates debt and decreases account',
        () async {
      await service.createDebt(
        bookId: bookId,
        personId: personId,
        amount: 400.0,
        isOwedToMe: false,
      );

      await service.recordDebtPayment(
        bookId: bookId,
        personId: personId,
        accountId: accountId1,
        amount: 150.0,
        isReceivablePayment: false,
      );

      final docAcc = await repository.accountsRef.doc(accountId1).get();
      final account = NotebookAccount.fromMap(docAcc.data()!, docAcc.id);
      expect(account.balance, 850.0);

      final docPerson = await repository.peopleRef.doc(personId).get();
      final person = NotebookPerson.fromMap(docPerson.data()!, docPerson.id);
      expect(person.amountIOwe, 250.0);
    });

    test('account transfer deducts from A and adds to B', () async {
      await service.transferFunds(
        bookId: bookId,
        fromAccountId: accountId2,
        toAccountId: accountId1,
        amount: 500.0,
      );

      final docAcc1 = await repository.accountsRef.doc(accountId1).get();
      final account1 = NotebookAccount.fromMap(docAcc1.data()!, docAcc1.id);
      expect(account1.balance, 1500.0);

      final docAcc2 = await repository.accountsRef.doc(accountId2).get();
      final account2 = NotebookAccount.fromMap(docAcc2.data()!, docAcc2.id);
      expect(account2.balance, 4500.0);
    });

    test('invalid/negative amount rejection', () async {
      expect(
        () => service.createIncome(
          bookId: bookId,
          accountId: accountId1,
          amount: -50.0,
          categoryId: incomeCategoryId,
        ),
        throwsArgumentError,
      );

      expect(
        () => service.createIncome(
          bookId: bookId,
          accountId: accountId1,
          amount: 0.0,
          categoryId: incomeCategoryId,
        ),
        throwsArgumentError,
      );

      expect(
        () => service.transferFunds(
          bookId: bookId,
          fromAccountId: accountId1,
          toAccountId: accountId2,
          amount: -100.0,
        ),
        throwsArgumentError,
      );
    });
  });
}

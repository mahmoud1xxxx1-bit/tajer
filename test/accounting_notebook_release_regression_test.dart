import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_provider.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_repository.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_account.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_book.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_category.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_person.dart';

void main() {
  group('Accounting Notebook release regressions', () {
    late FakeFirebaseFirestore firestore;
    late AccountingNotebookRepository repository;
    late AccountingNotebookService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repository = AccountingNotebookRepository(firestore, 'merchant1');
      service = AccountingNotebookService(repository);
      await repository.createBook(NotebookBook(
        id: 'bookA',
        name: 'Buffet',
        createdAt: DateTime(2026, 1, 1),
      ));
      await repository.createBook(NotebookBook(
        id: 'bookB',
        name: 'Personal',
        createdAt: DateTime(2026, 1, 2),
      ));
    });

    test('current book context is shared and explicit', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(notebookCurrentBookIdProvider), isNull);
      container.read(notebookCurrentBookIdProvider.notifier).state = 'bookA';
      expect(container.read(notebookCurrentBookIdProvider), 'bookA');
    });

    test('income accepts only active income category in same book', () async {
      await repository.createAccount(NotebookAccount(
        id: 'cashA',
        name: 'Cash',
        type: 'Cash',
        balance: 0,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await repository.createCategory(NotebookCategory(
        id: 'expenseA',
        name: 'Purchases',
        type: 'expense',
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await expectLater(
        service.createIncome(
          bookId: 'bookA',
          accountId: 'cashA',
          amount: 100,
          categoryId: 'expenseA',
        ),
        throwsException,
      );

      await repository.createCategory(NotebookCategory(
        id: 'incomeA',
        name: 'Sales',
        type: 'income',
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await service.createIncome(
        bookId: 'bookA',
        accountId: 'cashA',
        amount: 100,
        categoryId: 'incomeA',
      );
      final account = await repository.accountsRef.doc('cashA').get();
      expect((account.data()!['balance'] as num).toDouble(), 100);
    });

    test('expense accepts only expense category and rejects cross-book data',
        () async {
      await repository.createAccount(NotebookAccount(
        id: 'cashA',
        name: 'Cash',
        type: 'Cash',
        balance: 200,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await repository.createCategory(NotebookCategory(
        id: 'incomeA',
        name: 'Sales',
        type: 'income',
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await expectLater(
        service.createExpense(
          bookId: 'bookA',
          accountId: 'cashA',
          amount: 50,
          categoryId: 'incomeA',
        ),
        throwsException,
      );

      await repository.createCategory(NotebookCategory(
        id: 'expenseB',
        name: 'Rent',
        type: 'expense',
        bookId: 'bookB',
        createdAt: DateTime.now(),
      ));
      await expectLater(
        service.createExpense(
          bookId: 'bookA',
          accountId: 'cashA',
          amount: 50,
          categoryId: 'expenseB',
        ),
        throwsException,
      );
    });

    test('archived category cannot be used for a new transaction', () async {
      await repository.createAccount(NotebookAccount(
        id: 'cashA',
        name: 'Cash',
        type: 'Cash',
        balance: 200,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await repository.createCategory(NotebookCategory(
        id: 'expenseA',
        name: 'Rent',
        type: 'expense',
        bookId: 'bookA',
        createdAt: DateTime.now(),
        isArchived: true,
      ));
      await expectLater(
        service.createExpense(
          bookId: 'bookA',
          accountId: 'cashA',
          amount: 50,
          categoryId: 'expenseA',
        ),
        throwsException,
      );
    });

    test('transfer is limited to two active accounts in the same book',
        () async {
      await repository.createAccount(NotebookAccount(
        id: 'cashA',
        name: 'Cash A',
        type: 'Cash',
        balance: 500,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await repository.createAccount(NotebookAccount(
        id: 'bankB',
        name: 'Bank B',
        type: 'Bank',
        balance: 0,
        bookId: 'bookB',
        createdAt: DateTime.now(),
      ));
      await expectLater(
        service.transferFunds(
          bookId: 'bookA',
          fromAccountId: 'cashA',
          toAccountId: 'bankB',
          amount: 100,
        ),
        throwsException,
      );

      await repository.createAccount(NotebookAccount(
        id: 'bankA',
        name: 'Bank A',
        type: 'Bank',
        balance: 0,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await service.transferFunds(
        bookId: 'bookA',
        fromAccountId: 'cashA',
        toAccountId: 'bankA',
        amount: 100,
      );
      final cash = await repository.accountsRef.doc('cashA').get();
      final bank = await repository.accountsRef.doc('bankA').get();
      expect((cash.data()!['balance'] as num).toDouble(), 400);
      expect((bank.data()!['balance'] as num).toDouble(), 100);
    });

    test('opening balance creates account and history together', () async {
      await service.createAccount(
        bookId: 'bookA',
        name: 'Opening Cash',
        type: 'Cash',
        openingBalance: 750,
      );
      final accounts = await repository.accountsRef
          .where('bookId', isEqualTo: 'bookA')
          .get();
      final openingTransactions = await repository.transactionsRef
          .where('bookId', isEqualTo: 'bookA')
          .where('type', isEqualTo: 'opening_balance')
          .get();
      expect(accounts.docs.length, 1);
      expect(openingTransactions.docs.length, 1);
      expect((accounts.docs.single.data()['balance'] as num).toDouble(), 750);
      expect(
          (openingTransactions.docs.single.data()['amount'] as num).toDouble(),
          750);
    });

    test('receivable collection reduces debt and increases selected account',
        () async {
      await repository.createPerson(NotebookPerson(
        id: 'salem',
        name: 'Salem',
        amountOwedToMe: 0,
        amountIOwe: 0,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await repository.createAccount(NotebookAccount(
        id: 'cashA',
        name: 'Cash',
        type: 'Cash',
        balance: 50,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await service.createDebt(
        bookId: 'bookA',
        personId: 'salem',
        amount: 300,
        isOwedToMe: true,
      );
      await service.recordDebtPayment(
        bookId: 'bookA',
        personId: 'salem',
        accountId: 'cashA',
        amount: 100,
        isReceivablePayment: true,
      );
      final person = await repository.peopleRef.doc('salem').get();
      final account = await repository.accountsRef.doc('cashA').get();
      expect((person.data()!['amountOwedToMe'] as num).toDouble(), 200);
      expect((account.data()!['balance'] as num).toDouble(), 150);
    });

    test('payable settlement reduces debt and account balance', () async {
      await repository.createPerson(NotebookPerson(
        id: 'supplier',
        name: 'Supplier',
        amountOwedToMe: 0,
        amountIOwe: 500,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await repository.createAccount(NotebookAccount(
        id: 'cashA',
        name: 'Cash',
        type: 'Cash',
        balance: 1000,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await service.recordDebtPayment(
        bookId: 'bookA',
        personId: 'supplier',
        accountId: 'cashA',
        amount: 200,
        isReceivablePayment: false,
      );
      final person = await repository.peopleRef.doc('supplier').get();
      final account = await repository.accountsRef.doc('cashA').get();
      expect((person.data()!['amountIOwe'] as num).toDouble(), 300);
      expect((account.data()!['balance'] as num).toDouble(), 800);
    });

    test('book receivable/payable totals equal person ledger totals', () async {
      await repository.createPerson(NotebookPerson(
        id: 'p1',
        name: 'P1',
        amountOwedToMe: 300,
        amountIOwe: 0,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      await repository.createPerson(NotebookPerson(
        id: 'p2',
        name: 'P2',
        amountOwedToMe: 0,
        amountIOwe: 500,
        bookId: 'bookA',
        createdAt: DateTime.now(),
      ));
      final people = await repository.peopleRef
          .where('bookId', isEqualTo: 'bookA')
          .get();
      final receivable = people.docs.fold<double>(0,
          (sum, d) => sum + (d.data()['amountOwedToMe'] as num).toDouble());
      final payable = people.docs.fold<double>(
          0, (sum, d) => sum + (d.data()['amountIOwe'] as num).toDouble());
      expect(receivable, 300);
      expect(payable, 500);
    });
  });
}

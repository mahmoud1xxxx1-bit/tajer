import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_provider.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_repository.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_account.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_book.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_category.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_person.dart';

void main() {
  test('complete simple merchant accounting cycle stays balanced', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = AccountingNotebookRepository(firestore, 'merchant1');
    final service = AccountingNotebookService(repository);
    final now = DateTime(2026, 8, 16);

    await repository.createBook(NotebookBook(
      id: 'bookA',
      name: 'Main Book',
      createdAt: now,
    ));

    await repository.createAccount(NotebookAccount(
      id: 'cash',
      name: 'Cash',
      type: 'Cash',
      balance: 1000,
      bookId: 'bookA',
      createdAt: now,
    ));
    await repository.createAccount(NotebookAccount(
      id: 'bank',
      name: 'Bank',
      type: 'Bank',
      balance: 500,
      bookId: 'bookA',
      createdAt: now,
    ));

    await repository.createCategory(NotebookCategory(
      id: 'sales',
      name: 'Sales',
      type: 'income',
      bookId: 'bookA',
      createdAt: now,
    ));
    await repository.createCategory(NotebookCategory(
      id: 'rent',
      name: 'Rent',
      type: 'expense',
      bookId: 'bookA',
      createdAt: now,
    ));

    await repository.createPerson(NotebookPerson(
      id: 'customer',
      name: 'Customer',
      amountOwedToMe: 0,
      amountIOwe: 0,
      bookId: 'bookA',
      createdAt: now,
    ));
    await repository.createPerson(NotebookPerson(
      id: 'supplier',
      name: 'Supplier',
      amountOwedToMe: 0,
      amountIOwe: 0,
      bookId: 'bookA',
      createdAt: now,
    ));

    // 1) Income: cash 1000 -> 1400.
    await service.createIncome(
      bookId: 'bookA',
      accountId: 'cash',
      amount: 400,
      categoryId: 'sales',
      note: 'Cash sale',
    );

    // 2) Paid expense: cash 1400 -> 1250.
    await service.createExpense(
      bookId: 'bookA',
      accountId: 'cash',
      amount: 150,
      categoryId: 'rent',
      note: 'Paid rent',
    );

    // 3) Receivable: customer owes 300; cash must not change.
    await service.createDebt(
      bookId: 'bookA',
      personId: 'customer',
      amount: 300,
      isOwedToMe: true,
      note: 'Customer credit',
    );

    // 4) Collect 120: receivable 300 -> 180; cash 1250 -> 1370.
    await service.recordDebtPayment(
      bookId: 'bookA',
      personId: 'customer',
      accountId: 'cash',
      amount: 120,
      isReceivablePayment: true,
      note: 'Partial collection',
    );

    // 5) Payable: merchant owes supplier 500; cash must not change.
    await service.createDebt(
      bookId: 'bookA',
      personId: 'supplier',
      amount: 500,
      isOwedToMe: false,
      note: 'Supplier credit',
    );

    // 6) Pay supplier 200: payable 500 -> 300; cash 1370 -> 1170.
    await service.recordDebtPayment(
      bookId: 'bookA',
      personId: 'supplier',
      accountId: 'cash',
      amount: 200,
      isReceivablePayment: false,
      note: 'Partial supplier payment',
    );

    // 7) Transfer 250 cash -> bank. Total account money must stay unchanged.
    await service.transferFunds(
      bookId: 'bookA',
      fromAccountId: 'cash',
      toAccountId: 'bank',
      amount: 250,
      note: 'Deposit to bank',
    );

    final cashDoc = await repository.accountsRef.doc('cash').get();
    final bankDoc = await repository.accountsRef.doc('bank').get();
    final customerDoc = await repository.peopleRef.doc('customer').get();
    final supplierDoc = await repository.peopleRef.doc('supplier').get();

    final cash = (cashDoc.data()!['balance'] as num).toDouble();
    final bank = (bankDoc.data()!['balance'] as num).toDouble();
    final customerReceivable =
        (customerDoc.data()!['amountOwedToMe'] as num).toDouble();
    final customerPayable =
        (customerDoc.data()!['amountIOwe'] as num).toDouble();
    final supplierReceivable =
        (supplierDoc.data()!['amountOwedToMe'] as num).toDouble();
    final supplierPayable =
        (supplierDoc.data()!['amountIOwe'] as num).toDouble();

    expect(cash, 920);
    expect(bank, 750);
    expect(cash + bank, 1670);
    expect(customerReceivable, 180);
    expect(customerPayable, 0);
    expect(supplierReceivable, 0);
    expect(supplierPayable, 300);

    final txSnapshot = await repository.transactionsRef
        .where('bookId', isEqualTo: 'bookA')
        .get();
    expect(txSnapshot.docs.length, 7);

    final types = txSnapshot.docs
        .map((doc) => doc.data()['type']?.toString())
        .toList();
    expect(types.where((type) => type == 'income').length, 1);
    expect(types.where((type) => type == 'expense').length, 1);
    expect(types.where((type) => type == 'receivable').length, 1);
    expect(types.where((type) => type == 'receivable_payment').length, 1);
    expect(types.where((type) => type == 'payable').length, 1);
    expect(types.where((type) => type == 'payable_payment').length, 1);
    expect(types.where((type) => type == 'account_transfer').length, 1);

    // Accounting identities for this simple notebook model:
    // Opening cash+bank 1500 + income 400 - paid expense 150
    // + receivable collection 120 - payable payment 200 = 1670.
    // Transfer changes account distribution only, not the total.
    expect(cash + bank, 1500 + 400 - 150 + 120 - 200);
    expect(customerReceivable - supplierPayable, -120);
  });

  test('simple merchant safeguards reject impossible cash operations', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = AccountingNotebookRepository(firestore, 'merchant1');
    final service = AccountingNotebookService(repository);
    final now = DateTime(2026, 8, 16);

    await repository.createBook(NotebookBook(
      id: 'bookA',
      name: 'Main Book',
      createdAt: now,
    ));
    await repository.createAccount(NotebookAccount(
      id: 'cash',
      name: 'Cash',
      type: 'Cash',
      balance: 100,
      bookId: 'bookA',
      createdAt: now,
    ));
    await repository.createAccount(NotebookAccount(
      id: 'bank',
      name: 'Bank',
      type: 'Bank',
      balance: 0,
      bookId: 'bookA',
      createdAt: now,
    ));
    await repository.createCategory(NotebookCategory(
      id: 'expense',
      name: 'Expense',
      type: 'expense',
      bookId: 'bookA',
      createdAt: now,
    ));
    await repository.createPerson(NotebookPerson(
      id: 'supplier',
      name: 'Supplier',
      amountOwedToMe: 0,
      amountIOwe: 50,
      bookId: 'bookA',
      createdAt: now,
    ));

    await expectLater(
      service.createExpense(
        bookId: 'bookA',
        accountId: 'cash',
        amount: 150,
        categoryId: 'expense',
      ),
      throwsA(predicate((error) => error.toString().contains('insufficient_balance'))),
    );

    await expectLater(
      service.transferFunds(
        bookId: 'bookA',
        fromAccountId: 'cash',
        toAccountId: 'bank',
        amount: 150,
      ),
      throwsA(predicate((error) => error.toString().contains('insufficient_balance'))),
    );

    await expectLater(
      service.recordDebtPayment(
        bookId: 'bookA',
        personId: 'supplier',
        accountId: 'cash',
        amount: 60,
        isReceivablePayment: false,
      ),
      throwsA(predicate((error) => error.toString().contains('overpayment'))),
    );

    final cashDoc = await repository.accountsRef.doc('cash').get();
    final supplierDoc = await repository.peopleRef.doc('supplier').get();
    expect((cashDoc.data()!['balance'] as num).toDouble(), 100);
    expect((supplierDoc.data()!['amountIOwe'] as num).toDouble(), 50);

    final txSnapshot = await repository.transactionsRef.get();
    expect(txSnapshot.docs, isEmpty);
  });
}

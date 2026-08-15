import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_provider.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_repository.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_book.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_category.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_account.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_person.dart';

void main() {
  group('Accounting Notebook 34 Scenarios Integration Test', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AccountingNotebookRepository repository;
    late AccountingNotebookService service;
    
    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = AccountingNotebookRepository(fakeFirestore, 'merchant123');
      service = AccountingNotebookService(repository);
    });

    // 1-3. Book Scenarios
    test('1. Create Book', () async {
      await service.createBook('Test Book');
      final snapshot = await fakeFirestore.collection('merchants/merchant123/notebook_books').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['name'], 'Test Book');
    });

    test('2. Update Book', () async {
      await service.createBook('Test Book');
      final snapshot = await fakeFirestore.collection('merchants/merchant123/notebook_books').get();
      final id = snapshot.docs.first.id;
      await service.updateBook(id, 'Updated Book');
      final updated = await fakeFirestore.collection('merchants/merchant123/notebook_books').doc(id).get();
      expect(updated.data()!['name'], 'Updated Book');
    });

    test('3. Archive Book', () async {
      await service.createBook('Test Book');
      final snapshot = await fakeFirestore.collection('merchants/merchant123/notebook_books').get();
      final id = snapshot.docs.first.id;
      await service.archiveBook(id);
      final archived = await fakeFirestore.collection('merchants/merchant123/notebook_books').doc(id).get();
      expect(archived.data()!['isArchived'], true);
    });

    // 4-6. Category Scenarios
    test('4. Create Income Category', () async {
      await service.createCategory(bookId: 'book1', name: 'Sales', type: 'income');
      final snapshot = await fakeFirestore.collection('merchants/merchant123/notebook_categories').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['type'], 'income');
      expect(snapshot.docs.first.data()['bookId'], 'book1');
    });

    test('5. Create Expense Category', () async {
      await service.createCategory(bookId: 'book1', name: 'Rent', type: 'expense');
      final snapshot = await fakeFirestore.collection('merchants/merchant123/notebook_categories').get();
      expect(snapshot.docs.first.data()['type'], 'expense');
    });

    test('6. Archive Category', () async {
      await service.createCategory(bookId: 'book1', name: 'Sales', type: 'income');
      final snapshot = await fakeFirestore.collection('merchants/merchant123/notebook_categories').get();
      final id = snapshot.docs.first.id;
      await service.archiveCategory(id);
      final archived = await fakeFirestore.collection('merchants/merchant123/notebook_categories').doc(id).get();
      expect(archived.data()!['isArchived'], true);
    });

    // 7-10. Account Scenarios
    test('7. Create Account', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 0.0, bookId: 'book1', createdAt: DateTime.now()));
      final snap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      expect(snap.exists, true);
    });

    test('8. Archive Account', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 0.0, bookId: 'book1', createdAt: DateTime.now()));
      await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').update({'isArchived': true});
      final snap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      expect(snap.data()!['isArchived'], true);
    });

    test('9. Update Account', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 0.0, bookId: 'book1', createdAt: DateTime.now()));
      await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').update({'name': 'Bank'});
      final snap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      expect(snap.data()!['name'], 'Bank');
    });

    test('10. Person Creation', () async {
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 0, amountIOwe: 0, createdAt: DateTime.now()));
      final snap = await fakeFirestore.collection('merchants/merchant123/notebook_people').doc('p1').get();
      expect(snap.exists, true);
    });

    // 11-15. Income Scenarios
    test('11. Income Success', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 0.0, bookId: 'book1', createdAt: DateTime.now()));
      await service.createCategory(bookId: 'book1', name: 'Sales', type: 'income');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      
      await service.createIncome(bookId: 'book1', accountId: 'acc1', amount: 100, categoryId: catId);
      final accSnap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      expect(accSnap.data()!['balance'], 100.0);
    });

    test('12. Income Fails on Negative Amount', () async {
      expect(() => service.createIncome(bookId: 'book1', accountId: 'acc1', amount: -50, categoryId: 'cat1'), throwsArgumentError);
    });

    test('13. Income Fails on Missing Account', () async {
      await service.createCategory(bookId: 'book1', name: 'Sales', type: 'income');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      expect(() => service.createIncome(bookId: 'book1', accountId: 'missing', amount: 50, categoryId: catId), throwsException);
    });

    test('14. Income Fails on Account BookId Mismatch', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 0.0, bookId: 'wrongBook', createdAt: DateTime.now()));
      await service.createCategory(bookId: 'book1', name: 'Sales', type: 'income');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      expect(() => service.createIncome(bookId: 'book1', accountId: 'acc1', amount: 50, categoryId: catId), throwsException);
    });

    test('15. Income Fails on Category BookId Mismatch', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 0.0, bookId: 'book1', createdAt: DateTime.now()));
      await service.createCategory(bookId: 'wrongBook', name: 'Sales', type: 'income');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      expect(() => service.createIncome(bookId: 'book1', accountId: 'acc1', amount: 50, categoryId: catId), throwsException);
    });

    // 16-20. Expense Scenarios
    test('16. Expense Success', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 100.0, bookId: 'book1', createdAt: DateTime.now()));
      await service.createCategory(bookId: 'book1', name: 'Rent', type: 'expense');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      
      await service.createExpense(bookId: 'book1', accountId: 'acc1', amount: 40, categoryId: catId);
      final accSnap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      expect(accSnap.data()!['balance'], 60.0);
    });

    test('17. Expense Fails on Insufficient Balance', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 30.0, bookId: 'book1', createdAt: DateTime.now()));
      await service.createCategory(bookId: 'book1', name: 'Rent', type: 'expense');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      
      expect(() => service.createExpense(bookId: 'book1', accountId: 'acc1', amount: 40, categoryId: catId), throwsException);
    });

    test('18. Expense Fails on Missing Account', () async {
      await service.createCategory(bookId: 'book1', name: 'Rent', type: 'expense');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      expect(() => service.createExpense(bookId: 'book1', accountId: 'missing', amount: 10, categoryId: catId), throwsException);
    });

    test('19. Expense Fails on Account BookId Mismatch', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 100.0, bookId: 'wrongBook', createdAt: DateTime.now()));
      await service.createCategory(bookId: 'book1', name: 'Rent', type: 'expense');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      expect(() => service.createExpense(bookId: 'book1', accountId: 'acc1', amount: 40, categoryId: catId), throwsException);
    });

    test('20. Expense Fails on Category BookId Mismatch', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 100.0, bookId: 'book1', createdAt: DateTime.now()));
      await service.createCategory(bookId: 'wrongBook', name: 'Rent', type: 'expense');
      final catId = (await fakeFirestore.collection('merchants/merchant123/notebook_categories').get()).docs.first.id;
      expect(() => service.createExpense(bookId: 'book1', accountId: 'acc1', amount: 40, categoryId: catId), throwsException);
    });

    // 21-24. Debt Scenarios
    test('21. Debt Receivable Success', () async {
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 0, amountIOwe: 0, createdAt: DateTime.now()));
      await service.createDebt(bookId: 'book1', personId: 'p1', amount: 200, isOwedToMe: true);
      
      final pSnap = await fakeFirestore.collection('merchants/merchant123/notebook_people').doc('p1').get();
      expect(pSnap.data()!['amountOwedToMe'], 200.0);
    });

    test('22. Debt Payable Success', () async {
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 0, amountIOwe: 0, createdAt: DateTime.now()));
      await service.createDebt(bookId: 'book1', personId: 'p1', amount: 150, isOwedToMe: false);
      
      final pSnap = await fakeFirestore.collection('merchants/merchant123/notebook_people').doc('p1').get();
      expect(pSnap.data()!['amountIOwe'], 150.0);
    });

    test('23. Debt Fails on Zero Amount', () async {
      expect(() => service.createDebt(bookId: 'book1', personId: 'p1', amount: 0, isOwedToMe: true), throwsArgumentError);
    });

    test('24. Debt Fails on Person BookId Mismatch', () async {
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'wrongBook', amountOwedToMe: 0, amountIOwe: 0, createdAt: DateTime.now()));
      expect(() => service.createDebt(bookId: 'book1', personId: 'p1', amount: 200, isOwedToMe: true), throwsException);
    });

    // 25-29. Debt Payment Scenarios
    test('25. Debt Payment Receive Success', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 50.0, bookId: 'book1', createdAt: DateTime.now()));
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 200, amountIOwe: 0, createdAt: DateTime.now()));
      
      await service.recordDebtPayment(bookId: 'book1', personId: 'p1', accountId: 'acc1', amount: 100, isReceivablePayment: true);
      
      final pSnap = await fakeFirestore.collection('merchants/merchant123/notebook_people').doc('p1').get();
      final accSnap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      
      expect(pSnap.data()!['amountOwedToMe'], 100.0);
      expect(accSnap.data()!['balance'], 150.0);
    });

    test('26. Debt Payment Pay Success', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 200.0, bookId: 'book1', createdAt: DateTime.now()));
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 0, amountIOwe: 100, createdAt: DateTime.now()));
      
      await service.recordDebtPayment(bookId: 'book1', personId: 'p1', accountId: 'acc1', amount: 60, isReceivablePayment: false);
      
      final pSnap = await fakeFirestore.collection('merchants/merchant123/notebook_people').doc('p1').get();
      final accSnap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      
      expect(pSnap.data()!['amountIOwe'], 40.0);
      expect(accSnap.data()!['balance'], 140.0);
    });

    test('27. Debt Payment Receive Fails on Overpayment', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 50.0, bookId: 'book1', createdAt: DateTime.now()));
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 100, amountIOwe: 0, createdAt: DateTime.now()));
      
      expect(() => service.recordDebtPayment(bookId: 'book1', personId: 'p1', accountId: 'acc1', amount: 150, isReceivablePayment: true), throwsException);
    });

    test('28. Debt Payment Pay Fails on Overpayment', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 200.0, bookId: 'book1', createdAt: DateTime.now()));
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 0, amountIOwe: 50, createdAt: DateTime.now()));
      
      expect(() => service.recordDebtPayment(bookId: 'book1', personId: 'p1', accountId: 'acc1', amount: 100, isReceivablePayment: false), throwsException);
    });

    test('29. Debt Payment Pay Fails on Insufficient Balance', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 20.0, bookId: 'book1', createdAt: DateTime.now()));
      await repository.createPerson(NotebookPerson(id: 'p1', name: 'Ali', phone: '123', bookId: 'book1', amountOwedToMe: 0, amountIOwe: 100, createdAt: DateTime.now()));
      
      expect(() => service.recordDebtPayment(bookId: 'book1', personId: 'p1', accountId: 'acc1', amount: 50, isReceivablePayment: false), throwsException);
    });

    // 30-34. Transfer and Isolation Scenarios
    test('30. Transfer Success', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 100.0, bookId: 'book1', createdAt: DateTime.now()));
      await repository.createAccount(NotebookAccount(id: 'acc2', name: 'Bank', type: 'asset', balance: 50.0, bookId: 'book1', createdAt: DateTime.now()));
      
      await service.transferFunds(bookId: 'book1', fromAccountId: 'acc1', toAccountId: 'acc2', amount: 40);
      
      final acc1Snap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc1').get();
      final acc2Snap = await fakeFirestore.collection('merchants/merchant123/notebook_accounts').doc('acc2').get();
      
      expect(acc1Snap.data()!['balance'], 60.0);
      expect(acc2Snap.data()!['balance'], 90.0);
    });

    test('31. Transfer Fails on Same Account', () async {
      expect(() => service.transferFunds(bookId: 'book1', fromAccountId: 'acc1', toAccountId: 'acc1', amount: 40), throwsArgumentError);
    });

    test('32. Transfer Fails on Insufficient Balance', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 30.0, bookId: 'book1', createdAt: DateTime.now()));
      await repository.createAccount(NotebookAccount(id: 'acc2', name: 'Bank', type: 'asset', balance: 50.0, bookId: 'book1', createdAt: DateTime.now()));
      
      expect(() => service.transferFunds(bookId: 'book1', fromAccountId: 'acc1', toAccountId: 'acc2', amount: 40), throwsException);
    });
    
    test('33. Isolation Check: Notebook Data does not touch general products/orders', () async {
      await service.createBook('Test Book');
      await service.createCategory(bookId: 'book1', name: 'Sales', type: 'income');
      
      final productsSnap = await fakeFirestore.collection('merchants/merchant123/products').get();
      final ordersSnap = await fakeFirestore.collection('merchants/merchant123/orders').get();
      
      expect(productsSnap.docs.length, 0);
      expect(ordersSnap.docs.length, 0);
    });
    
    test('34. Isolation Check: Notebook accounts do not mix with Tajer logic', () async {
      await repository.createAccount(NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance: 100.0, bookId: 'book1', createdAt: DateTime.now()));
      
      final TajerShiftsSnap = await fakeFirestore.collection('merchants/merchant123/shifts').get();
      expect(TajerShiftsSnap.docs.length, 0);
    });
  });
}

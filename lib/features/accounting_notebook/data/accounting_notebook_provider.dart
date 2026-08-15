import '../domain/notebook_person.dart';
import '../domain/notebook_category.dart';
import '../domain/notebook_account.dart';
import '../domain/notebook_book.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'accounting_notebook_repository.dart';
import '../domain/notebook_transaction.dart';



final accountingNotebookProvider = Provider<AccountingNotebookService>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  return AccountingNotebookService(repo);
});


// Streams for UI
final notebookBooksProvider = StreamProvider.autoDispose<List<NotebookBook>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.booksRef.snapshots().map((snap) => 
    snap.docs.map((d) => NotebookBook.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
});

final notebookAccountsProvider = StreamProvider.autoDispose<List<NotebookAccount>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.accountsRef.snapshots().map((snap) => 
    snap.docs.map((d) => NotebookAccount.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
});

final notebookCategoriesProvider = StreamProvider.autoDispose<List<NotebookCategory>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.categoriesRef.snapshots().map((snap) => 
    snap.docs.map((d) => NotebookCategory.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
});

final notebookPeopleProvider = StreamProvider.autoDispose<List<NotebookPerson>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.peopleRef.snapshots().map((snap) => 
    snap.docs.map((d) => NotebookPerson.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
});

final notebookTransactionsProvider = StreamProvider.autoDispose<List<NotebookTransaction>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.transactionsRef.orderBy('date', descending: true).snapshots().map((snap) => 
    snap.docs.map((d) => NotebookTransaction.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
});

class AccountingNotebookService {
  final AccountingNotebookRepository? _repository;
  final _uuid = const Uuid();

  AccountingNotebookService(this._repository);

  // Books
  Future<void> createBook(String name) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    final book = NotebookBook(id: id, name: name, createdAt: DateTime.now());
    await _repository!.createBook(book);
  }
  
  Future<void> updateBook(String id, String name) async {
    if (_repository == null) return;
    await _repository!.booksRef.doc(id).update({'name': name});
  }

  Future<void> archiveBook(String id) async {
    if (_repository == null) return;
    // Just a basic implementation, can add 'isArchived' later
    await _repository!.booksRef.doc(id).delete();
  }

  // Categories
  Future<void> createCategory({required String bookId, required String name, required String type}) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    final cat = NotebookCategory(id: id, name: name, type: type, bookId: bookId, createdAt: DateTime.now());
    await _repository!.createCategory(cat);
  }

  Future<void> updateCategory(String id, String name) async {
    if (_repository == null) return;
    await _repository!.categoriesRef.doc(id).update({'name': name});
  }

  Future<void> archiveCategory(String id) async {
    if (_repository == null) return;
    await _repository!.categoriesRef.doc(id).delete();
  }


  // Example: Income creation
  Future<void> createIncome({
    required String bookId,
    required String accountId,
    required double amount,
    required String categoryId,
    String? note,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');
    if (_repository == null) return;
    
    final txId = _uuid.v4();
    final now = DateTime.now();
    
    final tx = NotebookTransaction(
      id: txId,
      type: 'income',
      amount: amount,
      bookId: bookId,
      accountId: accountId,
      categoryId: categoryId,
      note: note,
      date: now,
      createdAt: now,
    );

    // In a real app, this should use a transaction/batch to update account balance
    // For V1 baseline, we will do it sequentially or via batch
    final batch = _repository!.accountsRef.firestore.batch();
    
    // 1. Add transaction
    batch.set(_repository!.transactionsRef.doc(txId), tx.toMap());
    
    // 2. Update account balance
    final accountRef = _repository!.accountsRef.doc(accountId);
    batch.update(accountRef, {
      'balance': FieldValue.increment(amount)
    });
    
    await batch.commit();
  }

  Future<void> createExpense({
    required String bookId,
    required String accountId,
    required double amount,
    required String categoryId,
    String? note,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');
    if (_repository == null) return;
    
    final txId = _uuid.v4();
    final now = DateTime.now();
    
    final tx = NotebookTransaction(
      id: txId,
      type: 'expense',
      amount: amount,
      bookId: bookId,
      accountId: accountId,
      categoryId: categoryId,
      note: note,
      date: now,
      createdAt: now,
    );

    final batch = _repository!.accountsRef.firestore.batch();
    
    // 1. Add transaction
    batch.set(_repository!.transactionsRef.doc(txId), tx.toMap());
    
    // 2. Update account balance (decrease)
    final accountRef = _repository!.accountsRef.doc(accountId);
    batch.update(accountRef, {
      'balance': FieldValue.increment(-amount)
    });
    
    await batch.commit();
  }
  
  // Debts (Receivable)
  Future<void> createDebt({
    required String bookId,
    required String personId,
    required double amount,
    required bool isOwedToMe, // true = Receivable, false = Payable
    String? note,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');
    if (_repository == null) return;
    
    final txId = _uuid.v4();
    final now = DateTime.now();
    
    final tx = NotebookTransaction(
      id: txId,
      type: isOwedToMe ? 'receivable' : 'payable',
      amount: amount,
      bookId: bookId,
      personId: personId,
      note: note,
      date: now,
      createdAt: now,
    );

    final batch = _repository!.accountsRef.firestore.batch();
    batch.set(_repository!.transactionsRef.doc(txId), tx.toMap());
    
    final personRef = _repository!.peopleRef.doc(personId);
    if (isOwedToMe) {
      batch.update(personRef, {'amountOwedToMe': FieldValue.increment(amount)});
    } else {
      batch.update(personRef, {'amountIOwe': FieldValue.increment(amount)});
    }
    
    await batch.commit();
  }

  // Debt Payments
  Future<void> recordDebtPayment({
    required String bookId,
    required String personId,
    required String accountId,
    required double amount,
    required bool isReceivablePayment, // true = receiving money, false = paying money
    String? note,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');
    if (_repository == null) return;
    
    final txId = _uuid.v4();
    final now = DateTime.now();
    
    final tx = NotebookTransaction(
      id: txId,
      type: isReceivablePayment ? 'receivable_payment' : 'payable_payment',
      amount: amount,
      bookId: bookId,
      accountId: accountId,
      personId: personId,
      note: note,
      date: now,
      createdAt: now,
    );

    final batch = _repository!.accountsRef.firestore.batch();
    batch.set(_repository!.transactionsRef.doc(txId), tx.toMap());
    
    final personRef = _repository!.peopleRef.doc(personId);
    final accountRef = _repository!.accountsRef.doc(accountId);
    
    if (isReceivablePayment) {
      // Receiving money: decrease debt, increase account
      batch.update(personRef, {'amountOwedToMe': FieldValue.increment(-amount)});
      batch.update(accountRef, {'balance': FieldValue.increment(amount)});
    } else {
      // Paying money: decrease payable, decrease account
      batch.update(personRef, {'amountIOwe': FieldValue.increment(-amount)});
      batch.update(accountRef, {'balance': FieldValue.increment(-amount)});
    }
    
    await batch.commit();
  }
  
  // Transfer
  Future<void> transferFunds({
    required String bookId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');
    if (_repository == null) return;
    
    final txId = _uuid.v4();
    final now = DateTime.now();
    
    final tx = NotebookTransaction(
      id: txId,
      type: 'account_transfer',
      amount: amount,
      bookId: bookId,
      accountId: fromAccountId,
      toAccountId: toAccountId,
      note: note,
      date: now,
      createdAt: now,
    );

    final batch = _repository!.accountsRef.firestore.batch();
    batch.set(_repository!.transactionsRef.doc(txId), tx.toMap());
    
    final fromRef = _repository!.accountsRef.doc(fromAccountId);
    final toRef = _repository!.accountsRef.doc(toAccountId);
    
    batch.update(fromRef, {'balance': FieldValue.increment(-amount)});
    batch.update(toRef, {'balance': FieldValue.increment(amount)});
    
    await batch.commit();
  }

  // Accounts
  Future<void> createAccount({required String bookId, required String name, required String type, required double openingBalance}) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    final acc = NotebookAccount(id: id, bookId: bookId, name: name, type: type, balance: openingBalance, createdAt: DateTime.now());
    await _repository!.createAccount(acc);
  }

  Future<void> updateAccount(String id, {required String name, required String type}) async {
    if (_repository == null) return;
    await _repository!.accountsRef.doc(id).update({'name': name, 'type': type});
  }

  Future<void> archiveAccount(String id) async {
    if (_repository == null) return;
    await _repository!.accountsRef.doc(id).delete();
  }

  // People
  Future<void> createPerson({required String bookId, required String name, String? phone}) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    final p = NotebookPerson(id: id, bookId: bookId, name: name, phone: phone, amountOwedToMe: 0, amountIOwe: 0, createdAt: DateTime.now());
    await _repository!.createPerson(p);
  }

  Future<void> updatePerson(String id, {required String name, String? phone}) async {
    if (_repository == null) return;
    await _repository!.peopleRef.doc(id).update({'name': name, 'phone': phone});
  }

  Future<void> archivePerson(String id) async {
    if (_repository == null) return;
    await _repository!.peopleRef.doc(id).delete();
  }
}

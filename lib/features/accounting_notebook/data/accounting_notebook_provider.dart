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
    snap.docs.map((d) => NotebookBook.fromMap(d.data(), d.id)).toList());
});

final notebookAccountsProvider = StreamProvider.autoDispose<List<NotebookAccount>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.accountsRef.snapshots().map((snap) => 
    snap.docs.map((d) => NotebookAccount.fromMap(d.data(), d.id)).toList());
});

final notebookCategoriesProvider = StreamProvider.autoDispose<List<NotebookCategory>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.categoriesRef.snapshots().map((snap) => 
    snap.docs.map((d) => NotebookCategory.fromMap(d.data(), d.id)).toList());
});

final notebookPeopleProvider = StreamProvider.autoDispose<List<NotebookPerson>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.peopleRef.snapshots().map((snap) => 
    snap.docs.map((d) => NotebookPerson.fromMap(d.data(), d.id)).toList());
});

final notebookTransactionsProvider = StreamProvider.autoDispose<List<NotebookTransaction>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.transactionsRef.orderBy('date', descending: true).snapshots().map((snap) => 
    snap.docs.map((d) => NotebookTransaction.fromMap(d.data(), d.id)).toList());
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
    await _repository.createBook(book);
  }
  
  Future<void> updateBook(String id, String name) async {
    if (_repository == null) return;
    await _repository.booksRef.doc(id).update({'name': name});
  }

  Future<void> archiveBook(String id) async {
    if (_repository == null) return;
    await _repository.booksRef.doc(id).update({'isArchived': true});
  }

  // Categories
  Future<void> createCategory({required String bookId, required String name, required String type}) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    final cat = NotebookCategory(id: id, name: name, type: type, bookId: bookId, createdAt: DateTime.now());
    await _repository.createCategory(cat);
  }

  Future<void> updateCategory(String id, String name) async {
    if (_repository == null) return;
    await _repository.categoriesRef.doc(id).update({'name': name});
  }

  Future<void> archiveCategory(String id) async {
    if (_repository == null) return;
    await _repository.categoriesRef.doc(id).update({'isArchived': true});
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
    final accountRef = _repository.accountsRef.doc(accountId);
    final categoryRef = _repository.categoriesRef.doc(categoryId);
    final txRef = _repository.transactionsRef.doc(txId);

    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final accountSnap = await transaction.get(accountRef);
      if (!accountSnap.exists) throw Exception('Account not found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('Account bookId mismatch');

      final categorySnap = await transaction.get(categoryRef);
      if (!categorySnap.exists) throw Exception('Category not found');
      if (categorySnap.data()?['bookId'] != bookId) throw Exception('Category bookId mismatch');

      final currentBalance = accountSnap.data()?['balance'] as double? ?? 0.0;
      
      transaction.set(txRef, tx.toMap());
      transaction.update(accountRef, {'balance': currentBalance + amount});
    });
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

    final accountRef = _repository.accountsRef.doc(accountId);
    final txRef = _repository.transactionsRef.doc(txId);
    
    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final accountSnap = await transaction.get(accountRef);
      if (!accountSnap.exists) throw Exception('Account not found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('Account bookId mismatch');
      
      final categorySnap = await transaction.get(_repository.categoriesRef.doc(categoryId));
      if (!categorySnap.exists) throw Exception('Category not found');
      if (categorySnap.data()?['bookId'] != bookId) throw Exception('Category bookId mismatch');

      final currentBalance = accountSnap.data()?['balance'] as double? ?? 0.0;
      if (currentBalance < amount) {
        throw Exception('insufficient_balance');
      }
      
      transaction.set(txRef, tx.toMap());
      transaction.update(accountRef, {'balance': currentBalance - amount});
    });
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

    final personRef = _repository.peopleRef.doc(personId);
    
    await _repository.peopleRef.firestore.runTransaction((transaction) async {
      final personSnap = await transaction.get(personRef);
      if (!personSnap.exists) throw Exception('Person not found');
      if (personSnap.data()?['bookId'] != bookId) throw Exception('Person bookId mismatch');

      final owedToMe = personSnap.data()?['amountOwedToMe'] as double? ?? 0.0;
      final iOwe = personSnap.data()?['amountIOwe'] as double? ?? 0.0;
      
      transaction.set(_repository.transactionsRef.doc(txId), tx.toMap());
      
      if (isOwedToMe) {
        transaction.update(personRef, {'amountOwedToMe': owedToMe + amount});
      } else {
        transaction.update(personRef, {'amountIOwe': iOwe + amount});
      }
    });
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

    final personRef = _repository.peopleRef.doc(personId);
    final accountRef = _repository.accountsRef.doc(accountId);
    final txRef = _repository.transactionsRef.doc(txId);

    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final personSnap = await transaction.get(personRef);
      final accountSnap = await transaction.get(accountRef);
      
      if (!personSnap.exists) throw Exception('Person not found');
      if (personSnap.data()?['bookId'] != bookId) throw Exception('Person bookId mismatch');

      if (!accountSnap.exists) throw Exception('Account not found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('Account bookId mismatch');
      
      final accountBalance = accountSnap.data()?['balance'] as double? ?? 0.0;
      final owedToMe = personSnap.data()?['amountOwedToMe'] as double? ?? 0.0;
      final iOwe = personSnap.data()?['amountIOwe'] as double? ?? 0.0;
      
      if (isReceivablePayment) {
        if (amount > owedToMe) throw Exception('overpayment');
        transaction.update(personRef, {'amountOwedToMe': owedToMe - amount});
        transaction.update(accountRef, {'balance': accountBalance + amount});
      } else {
        if (amount > iOwe) throw Exception('overpayment');
        if (accountBalance < amount) throw Exception('insufficient_balance');
        transaction.update(personRef, {'amountIOwe': iOwe - amount});
        transaction.update(accountRef, {'balance': accountBalance - amount});
      }
      
      transaction.set(txRef, tx.toMap());
    });
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
    if (fromAccountId == toAccountId) throw ArgumentError('Cannot transfer to same account');
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

    final fromRef = _repository.accountsRef.doc(fromAccountId);
    final toRef = _repository.accountsRef.doc(toAccountId);
    final txRef = _repository.transactionsRef.doc(txId);

    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final fromSnap = await transaction.get(fromRef);
      final toSnap = await transaction.get(toRef);
      
      if (!fromSnap.exists || !toSnap.exists) throw Exception('Account not found');
      
      final fromBookId = fromSnap.data()?['bookId'] as String?;
      final toBookId = toSnap.data()?['bookId'] as String?;
      
      if (fromBookId != bookId || toBookId != bookId) {
        throw Exception('cross_book_transfer_not_allowed');
      }
      
      final fromBalance = fromSnap.data()?['balance'] as double? ?? 0.0;
      final toBalance = toSnap.data()?['balance'] as double? ?? 0.0;
      
      if (fromBalance < amount) throw Exception('insufficient_balance');
      
      transaction.update(fromRef, {'balance': fromBalance - amount});
      transaction.update(toRef, {'balance': toBalance + amount});
      transaction.set(txRef, tx.toMap());
    });
  }

  // Accounts
  Future<void> createAccount({required String bookId, required String name, required String type, required double openingBalance}) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    final acc = NotebookAccount(id: id, bookId: bookId, name: name, type: type, balance: openingBalance, createdAt: DateTime.now());
    await _repository.createAccount(acc);
    
    if (openingBalance > 0) {
      final txId = _uuid.v4();
      final tx = NotebookTransaction(
        id: txId,
        bookId: bookId,
        accountId: id,
        amount: openingBalance,
        type: 'opening_balance',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        note: null, // UI will display translated type
      );
      await _repository.createTransaction(tx);
    }
  }

  Future<void> updateAccount(String id, {required String name, required String type}) async {
    if (_repository == null) return;
    await _repository.accountsRef.doc(id).update({'name': name, 'type': type});
  }

  Future<void> archiveAccount(String id) async {
    if (_repository == null) return;
    await _repository.accountsRef.doc(id).update({'isArchived': true});
  }

  // People
  Future<void> createPerson({required String bookId, required String name, String? phone, String? notes}) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    final p = NotebookPerson(id: id, bookId: bookId, name: name, phone: phone, notes: notes, amountOwedToMe: 0, amountIOwe: 0, createdAt: DateTime.now());
    await _repository.createPerson(p);
  }

  Future<void> updatePerson(String id, {required String name, String? phone, String? notes}) async {
    if (_repository == null) return;
    await _repository.peopleRef.doc(id).update({'name': name, 'phone': phone, 'notes': notes});
  }

  Future<void> archivePerson(String id) async {
    if (_repository == null) return;
    await _repository.peopleRef.doc(id).update({'isArchived': true});
  }

  Future<void> restoreBook(String id) async {
    if (_repository == null) return;
    await _repository.booksRef.doc(id).update({'isArchived': false});
  }

  Future<void> restoreCategory(String id) async {
    if (_repository == null) return;
    await _repository.categoriesRef.doc(id).update({'isArchived': false});
  }

  Future<void> restoreAccount(String id) async {
    if (_repository == null) return;
    await _repository.accountsRef.doc(id).update({'isArchived': false});
  }

  Future<void> restorePerson(String id) async {
    if (_repository == null) return;
    await _repository.peopleRef.doc(id).update({'isArchived': false});
  }
}

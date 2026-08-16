import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/notebook_account.dart';
import '../domain/notebook_book.dart';
import '../domain/notebook_category.dart';
import '../domain/notebook_person.dart';
import '../domain/notebook_transaction.dart';
import 'accounting_notebook_repository.dart';

final accountingNotebookProvider = Provider<AccountingNotebookService>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  return AccountingNotebookService(repo);
});

/// Shared selected accounting book for the whole Accounting Notebook feature.
final notebookCurrentBookIdProvider = StateProvider<String?>((ref) => null);

final notebookBooksProvider = StreamProvider.autoDispose<List<NotebookBook>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.booksRef.snapshots().map((snap) => snap.docs.map((d) => NotebookBook.fromMap(d.data(), d.id)).toList());
});

final notebookAccountsProvider = StreamProvider.autoDispose<List<NotebookAccount>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.accountsRef.snapshots().map((snap) => snap.docs.map((d) => NotebookAccount.fromMap(d.data(), d.id)).toList());
});

final notebookCategoriesProvider = StreamProvider.autoDispose<List<NotebookCategory>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.categoriesRef.snapshots().map((snap) => snap.docs.map((d) => NotebookCategory.fromMap(d.data(), d.id)).toList());
});

final notebookPeopleProvider = StreamProvider.autoDispose<List<NotebookPerson>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.peopleRef.snapshots().map((snap) => snap.docs.map((d) => NotebookPerson.fromMap(d.data(), d.id)).toList());
});

final notebookTransactionsProvider = StreamProvider.autoDispose<List<NotebookTransaction>>((ref) {
  final repo = ref.watch(accountingNotebookRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.transactionsRef.orderBy('date', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => NotebookTransaction.fromMap(d.data(), d.id)).toList(),
      );
});

class AccountingNotebookService {
  final AccountingNotebookRepository? _repository;
  final _uuid = const Uuid();

  AccountingNotebookService(this._repository);

  AccountingNotebookRepository get _readRepository {
    final repository = _repository;
    if (repository == null) throw StateError('Accounting Notebook is not ready');
    return repository;
  }

  // Read-only query access used by paginated UI screens. Keeping these behind
  // the service avoids duplicating merchant scoping or constructing Firestore
  // paths in presentation code.
  get peopleRef => _readRepository.peopleRef;
  get accountsRef => _readRepository.accountsRef;
  get transactionsRef => _readRepository.transactionsRef;

  queryTransactions({
    required String bookId,
    String? accountId,
    String? personId,
    String? categoryId,
    String? type,
  }) =>
      _readRepository.queryTransactions(
        bookId: bookId,
        accountId: accountId,
        personId: personId,
        categoryId: categoryId,
        type: type,
      );

  double _money(Map<String, dynamic>? data, String key) => (data?[key] as num?)?.toDouble() ?? 0.0;

  void _ensureActive(Map<String, dynamic>? data, String error) {
    if (data == null || data['isArchived'] == true) throw Exception(error);
  }

  void _ensureBookActiveIfPresent(Map<String, dynamic>? data, bool exists) {
    if (exists && data?['isArchived'] == true) throw Exception('book_inactive');
  }

  Future<void> createBook(String name) async {
    if (_repository == null) return;
    final id = _uuid.v4();
    await _repository.createBook(NotebookBook(id: id, name: name, createdAt: DateTime.now()));
  }

  Future<void> updateBook(String id, String name) async {
    if (_repository == null) return;
    await _repository.booksRef.doc(id).update({'name': name});
  }

  Future<void> archiveBook(String id) async {
    if (_repository == null) return;
    await _repository.booksRef.doc(id).update({'isArchived': true});
  }

  Future<void> restoreBook(String id) async {
    if (_repository == null) return;
    await _repository.booksRef.doc(id).update({'isArchived': false});
  }

  Future<void> createCategory({required String bookId, required String name, required String type}) async {
    if (_repository == null) return;
    if (type != 'income' && type != 'expense') throw ArgumentError('invalid_category_type');
    final bookSnap = await _repository.booksRef.doc(bookId).get();
    _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
    final id = _uuid.v4();
    await _repository.createCategory(NotebookCategory(id: id, name: name, type: type, bookId: bookId, createdAt: DateTime.now()));
  }

  Future<void> updateCategory(String id, String name) async {
    if (_repository == null) return;
    await _repository.categoriesRef.doc(id).update({'name': name});
  }

  Future<void> archiveCategory(String id) async {
    if (_repository == null) return;
    await _repository.categoriesRef.doc(id).update({'isArchived': true});
  }

  Future<void> restoreCategory(String id) async {
    if (_repository == null) return;
    await _repository.categoriesRef.doc(id).update({'isArchived': false});
  }

  Future<void> createIncome({required String bookId, required String accountId, required double amount, required String categoryId, String? note}) async {
    if (amount <= 0) throw ArgumentError('invalid_amount');
    if (_repository == null) return;
    final txId = _uuid.v4();
    final now = DateTime.now();
    final accountRef = _repository.accountsRef.doc(accountId);
    final categoryRef = _repository.categoriesRef.doc(categoryId);
    final bookRef = _repository.booksRef.doc(bookId);
    final txRef = _repository.transactionsRef.doc(txId);
    final tx = NotebookTransaction(id: txId, type: 'income', amount: amount, bookId: bookId, accountId: accountId, categoryId: categoryId, note: note, date: now, createdAt: now);
    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final bookSnap = await transaction.get(bookRef);
      final accountSnap = await transaction.get(accountRef);
      final categorySnap = await transaction.get(categoryRef);
      _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
      if (!accountSnap.exists) throw Exception('account_not_found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('account_book_mismatch');
      _ensureActive(accountSnap.data(), 'account_inactive');
      if (!categorySnap.exists) throw Exception('category_not_found');
      if (categorySnap.data()?['bookId'] != bookId) throw Exception('category_book_mismatch');
      if (categorySnap.data()?['type'] != 'income') throw Exception('category_type_mismatch');
      _ensureActive(categorySnap.data(), 'category_inactive');
      final currentBalance = _money(accountSnap.data(), 'balance');
      transaction.set(txRef, tx.toMap());
      transaction.update(accountRef, {'balance': currentBalance + amount});
    });
  }

  Future<void> createExpense({required String bookId, required String accountId, required double amount, required String categoryId, String? note}) async {
    if (amount <= 0) throw ArgumentError('invalid_amount');
    if (_repository == null) return;
    final txId = _uuid.v4();
    final now = DateTime.now();
    final accountRef = _repository.accountsRef.doc(accountId);
    final categoryRef = _repository.categoriesRef.doc(categoryId);
    final bookRef = _repository.booksRef.doc(bookId);
    final txRef = _repository.transactionsRef.doc(txId);
    final tx = NotebookTransaction(id: txId, type: 'expense', amount: amount, bookId: bookId, accountId: accountId, categoryId: categoryId, note: note, date: now, createdAt: now);
    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final bookSnap = await transaction.get(bookRef);
      final accountSnap = await transaction.get(accountRef);
      final categorySnap = await transaction.get(categoryRef);
      _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
      if (!accountSnap.exists) throw Exception('account_not_found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('account_book_mismatch');
      _ensureActive(accountSnap.data(), 'account_inactive');
      if (!categorySnap.exists) throw Exception('category_not_found');
      if (categorySnap.data()?['bookId'] != bookId) throw Exception('category_book_mismatch');
      if (categorySnap.data()?['type'] != 'expense') throw Exception('category_type_mismatch');
      _ensureActive(categorySnap.data(), 'category_inactive');
      final currentBalance = _money(accountSnap.data(), 'balance');
      if (currentBalance < amount) throw Exception('insufficient_balance');
      transaction.set(txRef, tx.toMap());
      transaction.update(accountRef, {'balance': currentBalance - amount});
    });
  }

  Future<void> createDebt({required String bookId, required String personId, required double amount, required bool isOwedToMe, String? note}) async {
    if (amount <= 0) throw ArgumentError('invalid_amount');
    if (_repository == null) return;
    final txId = _uuid.v4();
    final now = DateTime.now();
    final personRef = _repository.peopleRef.doc(personId);
    final bookRef = _repository.booksRef.doc(bookId);
    final tx = NotebookTransaction(id: txId, type: isOwedToMe ? 'receivable' : 'payable', amount: amount, bookId: bookId, personId: personId, note: note, date: now, createdAt: now);
    await _repository.peopleRef.firestore.runTransaction((transaction) async {
      final bookSnap = await transaction.get(bookRef);
      final personSnap = await transaction.get(personRef);
      _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
      if (!personSnap.exists) throw Exception('person_not_found');
      if (personSnap.data()?['bookId'] != bookId) throw Exception('person_book_mismatch');
      _ensureActive(personSnap.data(), 'person_inactive');
      final owedToMe = _money(personSnap.data(), 'amountOwedToMe');
      final iOwe = _money(personSnap.data(), 'amountIOwe');
      transaction.set(_repository.transactionsRef.doc(txId), tx.toMap());
      transaction.update(personRef, isOwedToMe ? {'amountOwedToMe': owedToMe + amount} : {'amountIOwe': iOwe + amount});
    });
  }

  Future<void> recordDebtPayment({required String bookId, required String personId, required String accountId, required double amount, required bool isReceivablePayment, String? note}) async {
    if (amount <= 0) throw ArgumentError('invalid_amount');
    if (_repository == null) return;
    final txId = _uuid.v4();
    final now = DateTime.now();
    final personRef = _repository.peopleRef.doc(personId);
    final accountRef = _repository.accountsRef.doc(accountId);
    final bookRef = _repository.booksRef.doc(bookId);
    final txRef = _repository.transactionsRef.doc(txId);
    final tx = NotebookTransaction(id: txId, type: isReceivablePayment ? 'receivable_payment' : 'payable_payment', amount: amount, bookId: bookId, accountId: accountId, personId: personId, note: note, date: now, createdAt: now);
    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final bookSnap = await transaction.get(bookRef);
      final personSnap = await transaction.get(personRef);
      final accountSnap = await transaction.get(accountRef);
      _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
      if (!personSnap.exists) throw Exception('person_not_found');
      if (personSnap.data()?['bookId'] != bookId) throw Exception('person_book_mismatch');
      _ensureActive(personSnap.data(), 'person_inactive');
      if (!accountSnap.exists) throw Exception('account_not_found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('account_book_mismatch');
      _ensureActive(accountSnap.data(), 'account_inactive');
      final accountBalance = _money(accountSnap.data(), 'balance');
      final owedToMe = _money(personSnap.data(), 'amountOwedToMe');
      final iOwe = _money(personSnap.data(), 'amountIOwe');
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

  Future<void> transferFunds({required String bookId, required String fromAccountId, required String toAccountId, required double amount, String? note}) async {
    if (amount <= 0) throw ArgumentError('invalid_amount');
    if (fromAccountId == toAccountId) throw ArgumentError('same_account');
    if (_repository == null) return;
    final txId = _uuid.v4();
    final now = DateTime.now();
    final fromRef = _repository.accountsRef.doc(fromAccountId);
    final toRef = _repository.accountsRef.doc(toAccountId);
    final bookRef = _repository.booksRef.doc(bookId);
    final txRef = _repository.transactionsRef.doc(txId);
    final tx = NotebookTransaction(id: txId, type: 'account_transfer', amount: amount, bookId: bookId, accountId: fromAccountId, toAccountId: toAccountId, note: note, date: now, createdAt: now);
    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final bookSnap = await transaction.get(bookRef);
      final fromSnap = await transaction.get(fromRef);
      final toSnap = await transaction.get(toRef);
      _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
      if (!fromSnap.exists || !toSnap.exists) throw Exception('account_not_found');
      if (fromSnap.data()?['bookId'] != bookId || toSnap.data()?['bookId'] != bookId) throw Exception('cross_book_transfer_not_allowed');
      _ensureActive(fromSnap.data(), 'account_inactive');
      _ensureActive(toSnap.data(), 'account_inactive');
      final fromBalance = _money(fromSnap.data(), 'balance');
      final toBalance = _money(toSnap.data(), 'balance');
      if (fromBalance < amount) throw Exception('insufficient_balance');
      transaction.update(fromRef, {'balance': fromBalance - amount});
      transaction.update(toRef, {'balance': toBalance + amount});
      transaction.set(txRef, tx.toMap());
    });
  }

  Future<void> createAccount({required String bookId, required String name, required String type, required double openingBalance, String? notes}) async {
    if (_repository == null) return;
    if (openingBalance < 0) throw ArgumentError('invalid_opening_balance');
    final bookSnap = await _repository.booksRef.doc(bookId).get();
    _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
    final id = _uuid.v4();
    final now = DateTime.now();
    final account = NotebookAccount(id: id, bookId: bookId, name: name, type: type, balance: openingBalance, notes: notes, createdAt: now);
    final batch = _repository.accountsRef.firestore.batch();
    batch.set(_repository.accountsRef.doc(id), account.toMap());
    if (openingBalance > 0) {
      final txId = _uuid.v4();
      final tx = NotebookTransaction(id: txId, bookId: bookId, accountId: id, amount: openingBalance, type: 'opening_balance', date: now, createdAt: now);
      batch.set(_repository.transactionsRef.doc(txId), tx.toMap());
    }
    await batch.commit();
  }

  Future<void> updateAccount(String id, {required String name, required String type, String? notes}) async {
    if (_repository == null) return;
    await _repository.accountsRef.doc(id).update({'name': name, 'type': type, 'notes': notes});
  }

  Future<void> archiveAccount(String id) async {
    if (_repository == null) return;
    await _repository.accountsRef.doc(id).update({'isArchived': true});
  }

  Future<void> restoreAccount(String id) async {
    if (_repository == null) return;
    await _repository.accountsRef.doc(id).update({'isArchived': false});
  }

  Future<void> createPerson({required String bookId, required String name, String? phone, String? notes}) async {
    if (_repository == null) return;
    final bookSnap = await _repository.booksRef.doc(bookId).get();
    _ensureBookActiveIfPresent(bookSnap.data(), bookSnap.exists);
    final id = _uuid.v4();
    await _repository.createPerson(NotebookPerson(id: id, bookId: bookId, name: name, phone: phone, notes: notes, amountOwedToMe: 0, amountIOwe: 0, createdAt: DateTime.now()));
  }

  Future<void> updatePerson(String id, {required String name, String? phone, String? notes}) async {
    if (_repository == null) return;
    await _repository.peopleRef.doc(id).update({'name': name, 'phone': phone, 'notes': notes});
  }

  Future<void> archivePerson(String id) async {
    if (_repository == null) return;
    await _repository.peopleRef.doc(id).update({'isArchived': true});
  }

  Future<void> restorePerson(String id) async {
    if (_repository == null) return;
    await _repository.peopleRef.doc(id).update({'isArchived': false});
  }
}

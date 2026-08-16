import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notebook_book.dart';
import '../domain/notebook_account.dart';
import '../domain/notebook_category.dart';
import '../domain/notebook_person.dart';
import '../domain/notebook_transaction.dart';
import '../../authentication/data/auth_repository.dart';

final accountingNotebookRepositoryProvider =
    Provider<AccountingNotebookRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  if (appUser.role == 'employee' &&
      !appUser.hasPermission('can_access_accounting_notebook')) {
    return null;
  }
  final merchantId = appUser.role == 'employee'
      ? (appUser.merchantId ?? appUser.id)
      : appUser.id;
  return AccountingNotebookRepository(FirebaseFirestore.instance, merchantId);
});

class AccountingNotebookRepository {
  final FirebaseFirestore _firestore;
  final String merchantId;

  AccountingNotebookRepository(this._firestore, this.merchantId);

  CollectionReference<Map<String, dynamic>> get booksRef => _firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('notebook_books');

  CollectionReference<Map<String, dynamic>> get accountsRef => _firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('notebook_accounts');

  CollectionReference<Map<String, dynamic>> get categoriesRef => _firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('notebook_categories');

  CollectionReference<Map<String, dynamic>> get peopleRef => _firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('notebook_people');

  CollectionReference<Map<String, dynamic>> get transactionsRef => _firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('notebook_transactions');

  Stream<List<NotebookBook>> watchBooks() {
    return booksRef.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => NotebookBook.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createBook(NotebookBook book) async {
    await booksRef.doc(book.id).set(book.toMap());
  }

  Stream<List<NotebookAccount>> watchAccounts(String bookId) {
    return accountsRef.where('bookId', isEqualTo: bookId).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => NotebookAccount.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createAccount(NotebookAccount account) async {
    await accountsRef.doc(account.id).set(account.toMap());
  }

  Stream<List<NotebookCategory>> watchCategories(String bookId, String type) {
    return categoriesRef
        .where('bookId', isEqualTo: bookId)
        .where('type', isEqualTo: type)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotebookCategory.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createCategory(NotebookCategory category) async {
    await categoriesRef.doc(category.id).set(category.toMap());
  }

  Stream<List<NotebookPerson>> watchPeople(String bookId) {
    return peopleRef.where('bookId', isEqualTo: bookId).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => NotebookPerson.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createPerson(NotebookPerson person) async {
    await peopleRef.doc(person.id).set(person.toMap());
  }

  Stream<List<NotebookTransaction>> watchTransactions(String bookId) {
    return transactionsRef
        .where('bookId', isEqualTo: bookId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotebookTransaction.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Query<NotebookTransaction> queryTransactions({
    required String bookId,
    String? accountId,
    String? personId,
    String? categoryId,
    String? type,
  }) {
    Query<Map<String, dynamic>> query =
        transactionsRef.where('bookId', isEqualTo: bookId);

    if (accountId != null) {
      query = query.where('accountId', isEqualTo: accountId);
    }
    if (personId != null) {
      query = query.where('personId', isEqualTo: personId);
    }
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query
        .orderBy('date', descending: true)
        .withConverter<NotebookTransaction>(
          fromFirestore: (snapshot, _) =>
              NotebookTransaction.fromMap(snapshot.data()!, snapshot.id),
          toFirestore: (tx, _) => tx.toMap(),
        );
  }

  Query<NotebookTransaction> queryPersonTransactions(
      String bookId, String personId) {
    return transactionsRef
        .where('bookId', isEqualTo: bookId)
        .where('personId', isEqualTo: personId)
        .orderBy('date', descending: true)
        .withConverter<NotebookTransaction>(
          fromFirestore: (snapshot, _) =>
              NotebookTransaction.fromMap(snapshot.data()!, snapshot.id),
          toFirestore: (tx, _) => tx.toMap(),
        );
  }

  Future<void> createTransaction(NotebookTransaction transaction) async {
    await transactionsRef.doc(transaction.id).set(transaction.toMap());
  }
}

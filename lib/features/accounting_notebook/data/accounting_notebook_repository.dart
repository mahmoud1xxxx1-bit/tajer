import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notebook_book.dart';
import '../domain/notebook_account.dart';
import '../domain/notebook_category.dart';
import '../domain/notebook_person.dart';
import '../domain/notebook_transaction.dart';
import '../../authentication/data/auth_repository.dart';

final accountingNotebookRepositoryProvider = Provider<AccountingNotebookRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null || appUser.role == 'employee') return null; // strictly owner only
  final merchantId = appUser.id;
  return AccountingNotebookRepository(FirebaseFirestore.instance, merchantId);
});

class AccountingNotebookRepository {
  final FirebaseFirestore _firestore;
  final String merchantId;

  AccountingNotebookRepository(this._firestore, this.merchantId);

  // References
  CollectionReference<Map<String, dynamic>> get booksRef =>
      _firestore.collection('merchants').doc(merchantId).collection('notebook_books');
      
  CollectionReference<Map<String, dynamic>> get accountsRef =>
      _firestore.collection('merchants').doc(merchantId).collection('notebook_accounts');
      
  CollectionReference<Map<String, dynamic>> get categoriesRef =>
      _firestore.collection('merchants').doc(merchantId).collection('notebook_categories');
      
  CollectionReference<Map<String, dynamic>> get peopleRef =>
      _firestore.collection('merchants').doc(merchantId).collection('notebook_people');
      
  CollectionReference<Map<String, dynamic>> get transactionsRef =>
      _firestore.collection('merchants').doc(merchantId).collection('notebook_transactions');

  // --- Books ---
  Stream<List<NotebookBook>> watchBooks() {
    return booksRef.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => NotebookBook.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> createBook(NotebookBook book) async {
    await booksRef.doc(book.id).set(book.toMap());
  }

  // --- Accounts ---
  Stream<List<NotebookAccount>> watchAccounts(String bookId) {
    return accountsRef.where('bookId', isEqualTo: bookId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => NotebookAccount.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> createAccount(NotebookAccount account) async {
    await accountsRef.doc(account.id).set(account.toMap());
  }

  // --- Categories ---
  Stream<List<NotebookCategory>> watchCategories(String bookId, String type) {
    return categoriesRef
        .where('bookId', isEqualTo: bookId)
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NotebookCategory.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> createCategory(NotebookCategory category) async {
    await categoriesRef.doc(category.id).set(category.toMap());
  }

  // --- People ---
  Stream<List<NotebookPerson>> watchPeople(String bookId) {
    return peopleRef.where('bookId', isEqualTo: bookId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => NotebookPerson.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> createPerson(NotebookPerson person) async {
    await peopleRef.doc(person.id).set(person.toMap());
  }

  // --- Transactions ---
  Stream<List<NotebookTransaction>> watchTransactions(String bookId) {
    return transactionsRef
        .where('bookId', isEqualTo: bookId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NotebookTransaction.fromMap(doc.data(), doc.id)).toList();
    });
  }
  
  // Transaction processing logic will go here (batch writes for balance updates)
  Future<void> createTransaction(NotebookTransaction transaction) async {
    await transactionsRef.doc(transaction.id).set(transaction.toMap());
  }
}

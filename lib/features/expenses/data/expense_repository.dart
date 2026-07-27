import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  ExpenseRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('expenses');

  Stream<List<Expense>> watchExpenses() {
    return _expensesRef.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Expense.fromJson(doc.data())).toList();
    });
  }

  Future<void> addExpense(Expense expense) async {
    await _expensesRef.doc(expense.id).set(expense.toJson());
  }

  Future<void> updateExpense(Expense expense) async {
    await _expensesRef.doc(expense.id).update(expense.toJson());
  }

  Future<void> deleteExpense(String expenseId) async {
    await _expensesRef.doc(expenseId).delete();
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository?>((ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return ExpenseRepository(FirebaseFirestore.instance, user.uid);
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchExpenses();
});

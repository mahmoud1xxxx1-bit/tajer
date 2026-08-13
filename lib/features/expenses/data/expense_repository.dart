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

  Query<Expense> queryExpenses({String sortBy = 'newest', bool includeCancelled = false}) {
    Query<Map<String, dynamic>> query = _expensesRef;

    if (!includeCancelled) {
      query = query.where('isCancelled', isEqualTo: false);
    }
    
    query = query.orderBy('date', descending: true);

    return query.withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['amount'] = (data['amount'] ?? 0.0).toDouble();
        return Expense.fromJson(data);
      },
      toFirestore: (expense, _) => expense.toJson(),
    );
  }

  Stream<List<Expense>> watchExpenses() {
    return _expensesRef.withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['amount'] = (data['amount'] ?? 0.0).toDouble();
        return Expense.fromJson(data);
      },
      toFirestore: (expense, _) => expense.toJson(),
    ).orderBy('date', descending: true).limit(1000).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addExpense(Expense expense) async {
    await _expensesRef.doc(expense.id).set(expense.toJson());
  }

  Future<void> updateExpense(Expense expense) async {
    await _expensesRef.doc(expense.id).update(expense.toJson());
  }

  Future<void> cancelExpense(Expense expense) async {
    // BUG #2 FIX: Verify expense is not part of a closed shift.
    // Since Expense doesn't store shiftId, we check against the shifts collection by time.
    
    final openShifts = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: expense.merchantId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
        
    final hasOpenShift = openShifts.docs.isNotEmpty;
    
    if (hasOpenShift) {
      final currentShiftData = openShifts.docs.first.data();
      final startTime = (currentShiftData['startTime'] as Timestamp).toDate();
      // If expense was created BEFORE this open shift, it belongs to a past CLOSED shift
      if (expense.createdAt.isBefore(startTime.subtract(const Duration(minutes: 1)))) {
         throw Exception('لا يمكن إلغاء هذا المصروف لأنه يخص وردية سابقة ومغلقة.');
      }
    } else {
      // No open shift. Check if the merchant uses shifts by looking for closed shifts.
      final recentShifts = await _firestore
          .collection('shifts')
          .where('merchantId', isEqualTo: expense.merchantId)
          .where('status', isEqualTo: 'closed')
          .limit(1)
          .get();
          
      if (recentShifts.docs.isNotEmpty) {
          throw Exception('لا توجد وردية مفتوحة حالياً. لا يمكن إلغاء المصروفات لورديات مغلقة.');
      } else {
          // Merchant never used shifts (fallback)
          final now = DateTime.now();
          bool isSameDay = now.year == expense.date.year && now.month == expense.date.month && now.day == expense.date.day;
          bool isRecent = now.difference(expense.date).inHours < 16;
          if (!isSameDay && !isRecent) {
             throw Exception('المصروف قديم جداً ولا يمكن إلغاؤه.');
          }
      }
    }
    
    final cancelledExpense = expense.copyWith(isCancelled: true);
    await _expensesRef.doc(expense.id).update(cancelledExpense.toJson());
  }

  Future<void> deleteExpense(String expenseId) async {
    await _expensesRef.doc(expenseId).delete();
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return ExpenseRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchExpenses();
});


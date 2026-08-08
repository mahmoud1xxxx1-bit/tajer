import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  ExpenseRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('expenses');

  Future<String> _selectedBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('selected_branch_$_merchantId')?.trim();
    return value == null || value.isEmpty ? 'main' : value;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _openShiftForBranch(String branchId) async {
    final snap = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: _merchantId)
        .where('status', isEqualTo: 'open')
        .get();
    for (final doc in snap.docs) {
      final docBranchId = doc.data()['branchId']?.toString() ?? 'main';
      if (docBranchId == branchId) return doc;
    }
    return null;
  }

  Stream<List<Expense>> watchExpenses({String branchId = 'main'}) {
    return _expensesRef.withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['amount'] = (data['amount'] ?? 0.0).toDouble();
        data['branchId'] = data['branchId']?.toString() ?? 'main';
        return Expense.fromJson(data);
      },
      toFirestore: (expense, _) => expense.toJson(),
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data())
          .where((expense) => expense.branchId == branchId)
          .toList();
    });
  }

  Future<void> addExpense(Expense expense) async {
    final branchId = await _selectedBranchId();
    String? shiftId = expense.shiftId;

    if (expense.isFromShiftDrawer && expense.paymentMethod == 'cash') {
      final openShift = await _openShiftForBranch(branchId);
      if (openShift == null) {
        throw Exception('لا يمكن خصم المصروف من الدرج بدون وردية مفتوحة في هذا الفرع.');
      }
      shiftId = openShift.id;
    }

    final normalized = expense.copyWith(
      branchId: branchId,
      shiftId: shiftId,
    );

    if (normalized.shiftId != null && normalized.shiftId!.isNotEmpty) {
      final shift = await _firestore.collection('shifts').doc(normalized.shiftId).get(const GetOptions(source: Source.serverAndCache));
      if (!shift.exists) throw Exception('الوردية المرتبطة بالمصروف غير موجودة.');
      final data = shift.data()!;
      final shiftBranchId = data['branchId']?.toString() ?? 'main';
      final status = data['status']?.toString();
      if (shiftBranchId != normalized.branchId || status != 'open') {
        throw Exception('لا يمكن تسجيل المصروف على وردية مغلقة أو فرع مختلف.');
      }
    }

    await _expensesRef.doc(normalized.id).set(normalized.toJson());
  }

  Future<void> updateExpense(Expense expense) async {
    await _expensesRef.doc(expense.id).update(expense.toJson());
  }

  Future<void> cancelExpense(Expense expense) async {
    if (expense.isCancelled) return;

    if (expense.shiftId != null && expense.shiftId!.isNotEmpty) {
      final shift = await _firestore.collection('shifts').doc(expense.shiftId).get(const GetOptions(source: Source.serverAndCache));
      if (!shift.exists) {
        throw Exception('تعذر التحقق من الوردية المرتبطة بهذا المصروف.');
      }
      final data = shift.data()!;
      final status = data['status']?.toString();
      final shiftBranchId = data['branchId']?.toString() ?? 'main';
      if (shiftBranchId != expense.branchId) {
        throw Exception('المصروف مرتبط بفرع مختلف ولا يمكن إلغاؤه من هذا الفرع.');
      }
      if (status != 'open' || data['endTime'] != null) {
        throw Exception('لا يمكن إلغاء هذا المصروف لأن الوردية المرتبطة به مغلقة.');
      }
    } else {
      final openShifts = await _firestore
          .collection('shifts')
          .where('merchantId', isEqualTo: expense.merchantId)
          .where('status', isEqualTo: 'open')
          .get();
      final matchingOpen = openShifts.docs.where((doc) {
        final b = doc.data()['branchId']?.toString() ?? 'main';
        return b == expense.branchId;
      }).toList();

      if (matchingOpen.isNotEmpty) {
        final currentShiftData = matchingOpen.first.data();
        final startTime = (currentShiftData['startTime'] as Timestamp).toDate();
        if (expense.createdAt.isBefore(startTime.subtract(const Duration(minutes: 1)))) {
          throw Exception('لا يمكن إلغاء هذا المصروف لأنه يخص وردية سابقة ومغلقة.');
        }
      } else {
        final closed = await _firestore
            .collection('shifts')
            .where('merchantId', isEqualTo: expense.merchantId)
            .where('status', isEqualTo: 'closed')
            .get();
        final hasClosedInBranch = closed.docs.any((doc) {
          final b = doc.data()['branchId']?.toString() ?? 'main';
          return b == expense.branchId;
        });
        if (hasClosedInBranch) {
          throw Exception('لا توجد وردية مفتوحة حالياً في هذا الفرع. لا يمكن إلغاء مصروف وردية مغلقة.');
        }

        final now = DateTime.now();
        final sameDay = now.year == expense.date.year && now.month == expense.date.month && now.day == expense.date.day;
        final recent = now.difference(expense.date).inHours < 16;
        if (!sameDay && !recent) {
          throw Exception('المصروف قديم جداً ولا يمكن إلغاؤه.');
        }
      }
    }

    await _expensesRef.doc(expense.id).update({
      'isCancelled': true,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
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
  final branchId = ref.watch(selectedBranchIdProvider);
  return repo.watchExpenses(branchId: branchId);
});

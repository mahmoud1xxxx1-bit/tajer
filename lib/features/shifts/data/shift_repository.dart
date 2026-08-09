import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/shift.dart';

part 'shift_repository.g.dart';

class ShiftRepository {
  final FirebaseFirestore _firestore;

  ShiftRepository(this._firestore);

  DocumentReference<Map<String, dynamic>> _runtimeRef(
          String merchantId, String branchId) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_runtime')
          .doc(branchId);

  Stream<Shift?> watchCurrentShift(String merchantId,
      {String branchId = 'main'}) {
    return _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
        .where('branchId', isEqualTo: branchId)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docBranchId = data['branchId']?.toString() ?? 'main';
        if (docBranchId == branchId) return Shift.fromJson(data);
      }
      return null;
    });
  }

  Future<void> openShift(Shift shift) async {
    // Legacy safety first: v107 shifts have no branchId and therefore belong
    // to Main Branch. Branch filtering stays in memory to avoid a new index.
    final openShifts = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: shift.merchantId)
        .where('branchId', isEqualTo: shift.branchId)
        .where('status', isEqualTo: 'open')
        .get();

    final hasOpenInBranch = openShifts.docs.any((doc) {
      final branchId = doc.data()['branchId']?.toString() ?? 'main';
      return branchId == shift.branchId;
    });
    if (hasOpenInBranch) {
      throw Exception(
          'يوجد وردية مفتوحة حالياً في هذا الفرع، الرجاء إغلاقها أولاً.');
    }

    // Concurrency guard for the multi-branch era. Two devices attempting to
    // open a shift in the same branch cannot both succeed.
    final shiftRef = _firestore.collection('shifts').doc(shift.id);
    final runtimeRef = _runtimeRef(shift.merchantId, shift.branchId);
    await _firestore.runTransaction((transaction) async {
      final runtime = await transaction.get(runtimeRef);
      final existingOpenShiftId = runtime.data()?['openShiftId']?.toString();
      if (existingOpenShiftId != null && existingOpenShiftId.isNotEmpty) {
        throw Exception(
            'يوجد وردية مفتوحة حالياً في هذا الفرع، الرجاء إغلاقها أولاً.');
      }

      transaction.set(shiftRef, shift.toJson());
      transaction.set(
          runtimeRef,
          {
            'merchantId': shift.merchantId,
            'branchId': shift.branchId,
            'openShiftId': shift.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> closeShift(Shift shift) async {
    final shiftRef = _firestore.collection('shifts').doc(shift.id);
    final runtimeRef = _runtimeRef(shift.merchantId, shift.branchId);

    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(shiftRef);
      if (!current.exists || current.data() == null) {
        throw Exception('الوردية غير موجودة.');
      }
      final data = current.data()!;
      final currentBranchId = data['branchId']?.toString() ?? 'main';
      if (currentBranchId != shift.branchId) {
        throw Exception('لا يمكن إغلاق وردية تابعة لفرع مختلف.');
      }
      if (data['status']?.toString() != 'open' || data['endTime'] != null) {
        throw Exception('هذه الوردية مغلقة بالفعل.');
      }

      final runtime = await transaction.get(runtimeRef);
      final runtimeOpenId = runtime.data()?['openShiftId']?.toString();
      if (runtimeOpenId != null &&
          runtimeOpenId.isNotEmpty &&
          runtimeOpenId != shift.id) {
        throw Exception('حالة الوردية في هذا الفرع غير متطابقة.');
      }

      transaction.update(shiftRef, {
        'branchId': shift.branchId,
        'endTime': shift.endTime,
        'expectedCash': shift.expectedCash,
        'actualCash': shift.actualCash,
        'actualCard': shift.actualCard,
        'actualTransfer': shift.actualTransfer,
        'cardTotal': shift.cardTotal,
        'transferTotal': shift.transferTotal,
        'cashSales': shift.cashSales,
        'refundsCash': shift.refundsCash,
        'refundsCard': shift.refundsCard,
        'refundsTransfer': shift.refundsTransfer,
        'totalTax': shift.totalTax,
        'status': 'closed',
      });
      transaction.set(
          runtimeRef,
          {
            'merchantId': shift.merchantId,
            'branchId': shift.branchId,
            'openShiftId': null,
            'lastClosedShiftId': shift.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<List<Shift>> getClosedShifts(
    String merchantId, {
    String branchId = 'main',
  }) async {
    final snapshot = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
        .where('branchId', isEqualTo: branchId)
        .where('status', isEqualTo: 'closed')
        .get();

    final shifts = snapshot.docs
        .map((doc) => Shift.fromJson(doc.data()))
        .where((shift) => shift.branchId == branchId)
        .toList()
      ..sort((a, b) {
        final aTime = a.endTime ?? a.startTime;
        final bTime = b.endTime ?? b.startTime;
        return bTime.compareTo(aTime);
      });
    return shifts;
  }
}

@riverpod
ShiftRepository shiftRepository(ShiftRepositoryRef ref) {
  return ShiftRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<Shift?> currentShift(CurrentShiftRef ref, String merchantId) {
  final repository = ref.watch(shiftRepositoryProvider);
  final branchId = ref.watch(selectedBranchIdProvider);
  return repository.watchCurrentShift(merchantId, branchId: branchId);
}

@riverpod
Stream<List<Shift>> shiftsStream(ShiftsStreamRef ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return const Stream.empty();
  final repository = ref.watch(shiftRepositoryProvider);
  return repository._firestore
      .collection('shifts')
      .where('merchantId', isEqualTo: currentEffectiveMerchantId(appUser))
      .where('branchId', isEqualTo: branchId)
      .orderBy('startTime', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Shift.fromJson(doc.data()))
          .where((shift) => shift.branchId == branchId)
          .toList());
}

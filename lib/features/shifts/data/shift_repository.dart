import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/shift.dart';

part 'shift_repository.g.dart';

class ShiftRepository {
  final FirebaseFirestore _firestore;

  ShiftRepository(this._firestore);

  Stream<Shift?> watchCurrentShift(String merchantId, {String branchId = 'main'}) {
    return _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
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
    // Deliberately filter branch in memory to avoid forcing a new production
    // composite index during rollout. Missing branchId is legacy Main Branch.
    final openShifts = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: shift.merchantId)
        .where('status', isEqualTo: 'open')
        .get();

    final hasOpenInBranch = openShifts.docs.any((doc) {
      final branchId = doc.data()['branchId']?.toString() ?? 'main';
      return branchId == shift.branchId;
    });
    if (hasOpenInBranch) {
      throw Exception('يوجد وردية مفتوحة حالياً في هذا الفرع، الرجاء إغلاقها أولاً.');
    }

    await _firestore.collection('shifts').doc(shift.id).set(shift.toJson());
  }

  Future<void> closeShift(Shift shift) async {
    await _firestore.collection('shifts').doc(shift.id).update({
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
  }

  Future<List<Shift>> getClosedShifts(
    String merchantId, {
    String branchId = 'main',
  }) async {
    final snapshot = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
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
  final repository = ref.watch(shiftRepositoryProvider);
  return repository._firestore
      .collection('shifts')
      .where('merchantId', isEqualTo: appUser.merchantId ?? appUser.id)
      .orderBy('startTime', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Shift.fromJson(doc.data()))
          .where((shift) => shift.branchId == branchId)
          .toList());
}

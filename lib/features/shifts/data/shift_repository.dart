import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/shift.dart';

part 'shift_repository.g.dart';

class ShiftRepository {
  final FirebaseFirestore _firestore;

  ShiftRepository(this._firestore);

  Stream<Shift?> watchCurrentShift(String merchantId) {
    return _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snapshot) {
      final openShifts = snapshot.docs.where((doc) => doc.data()['status'] == 'open').toList();
      if (openShifts.isNotEmpty) {
        return Shift.fromJson(openShifts.first.data());
      }
      return null;
    });
  }

  Future<void> openShift(Shift shift) async {
    // Ensure no other open shift for this merchant
    final allShifts = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: shift.merchantId)
        .get();
        
    final openShifts = allShifts.docs.where((doc) => doc.data()['status'] == 'open').toList();
        
    if (openShifts.isNotEmpty) {
      throw Exception('يوجد وردية مفتوحة حالياً، الرجاء إغلاقها أولاً.');
    }

    await _firestore.collection('shifts').doc(shift.id).set(shift.toJson());
  }

  Future<void> closeShift(Shift shift) async {
    await _firestore.collection('shifts').doc(shift.id).update({
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

  Future<List<Shift>> getClosedShifts(String merchantId) async {
    final snapshot = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
        .get();
        
    var closedShifts = snapshot.docs
        .map((doc) => Shift.fromJson(doc.data()))
        .where((s) => s.status == 'closed')
        .toList();
        
    closedShifts.sort((a, b) => (b.endTime ?? DateTime.now()).compareTo(a.endTime ?? DateTime.now()));
    return closedShifts;
  }
}

@riverpod
ShiftRepository shiftRepository(ShiftRepositoryRef ref) {
  return ShiftRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<Shift?> currentShift(CurrentShiftRef ref, String merchantId) {
  final repository = ref.watch(shiftRepositoryProvider);
  return repository.watchCurrentShift(merchantId);
}

@riverpod
Stream<List<Shift>> shiftsStream(ShiftsStreamRef ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final repository = ref.watch(shiftRepositoryProvider);
  return repository._firestore
      .collection('shifts')
      .where('merchantId', isEqualTo: appUser.merchantId ?? appUser.id)
      .snapshots()
      .map((snapshot) {
        var shifts = snapshot.docs.map((doc) => Shift.fromJson(doc.data())).toList();
        shifts.sort((a, b) => b.startTime.compareTo(a.startTime));
        return shifts.take(100).toList();
      });
}

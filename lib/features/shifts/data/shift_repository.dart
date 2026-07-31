import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/shift.dart';

part 'shift_repository.g.dart';

class ShiftRepository {
  final FirebaseFirestore _firestore;

  ShiftRepository(this._firestore);

  Stream<Shift?> watchCurrentShift(String merchantId) {
    return _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Shift.fromJson(snapshot.docs.first.data());
      }
      return null;
    });
  }

  Future<void> openShift(Shift shift) async {
    // Ensure no other open shift for this merchant
    final openShifts = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: shift.merchantId)
        .where('status', isEqualTo: 'open')
        .get();
        
    if (openShifts.docs.isNotEmpty) {
      throw Exception('يوجد وردية مفتوحة حالياً، الرجاء إغلاقها أولاً.');
    }

    await _firestore.collection('shifts').doc(shift.id).set(shift.toJson());
  }

  Future<void> closeShift(Shift shift) async {
    await _firestore.collection('shifts').doc(shift.id).update({
      'endTime': shift.endTime,
      'expectedCash': shift.expectedCash,
      'actualCash': shift.actualCash,
      'cardTotal': shift.cardTotal,
      'transferTotal': shift.transferTotal,
      'cashSales': shift.cashSales,
      'status': 'closed',
    });
  }

  Future<List<Shift>> getClosedShifts(String merchantId) async {
    final snapshot = await _firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: merchantId)
        .where('status', isEqualTo: 'closed')
        .orderBy('endTime', descending: true)
        .get();
    return snapshot.docs.map((doc) => Shift.fromJson(doc.data())).toList();
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

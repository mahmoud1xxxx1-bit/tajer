import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/inventory_log.dart';

class InventoryLogRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  InventoryLogRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('inventory_logs');

  Stream<List<InventoryLog>> watchLogs() {
    return _logsRef.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => InventoryLog.fromJson(doc.data())).toList();
    });
  }

  Future<void> logChange({
    required String productId,
    required String productName,
    required int previousQuantity,
    required int newQuantity,
    required String reason,
    String? userEmail,
  }) async {
    final change = newQuantity - previousQuantity;
    if (change == 0) return; // No real change

    final log = InventoryLog(
      id: const Uuid().v4(),
      merchantId: _merchantId,
      productId: productId,
      productName: productName,
      changeQuantity: change,
      previousQuantity: previousQuantity,
      newQuantity: newQuantity,
      reason: reason,
      userEmail: userEmail,
      date: DateTime.now(),
    );

    await _logsRef.doc(log.id).set(log.toJson());
  }
}

final inventoryLogRepositoryProvider = Provider<InventoryLogRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return InventoryLogRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final inventoryLogsStreamProvider = StreamProvider<List<InventoryLog>>((ref) {
  final repo = ref.watch(inventoryLogRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchLogs();
});


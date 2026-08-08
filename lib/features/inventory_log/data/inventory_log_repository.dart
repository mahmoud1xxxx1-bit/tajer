import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/inventory_log.dart';

class InventoryLogRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  InventoryLogRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('inventory_logs');

  Stream<List<InventoryLog>> watchLogs({String branchId = 'main'}) {
    return _logsRef.withConverter<InventoryLog?>(
      fromFirestore: (snapshot, _) {
        try {
          final data = Map<String, dynamic>.from(snapshot.data() ?? {});
          data['id'] = snapshot.id;
          data['productId'] = data['productId']?.toString() ?? '';
          data['productName'] = data['productName']?.toString() ?? '';
          data['reason'] = data['reason']?.toString() ?? '';
          data['merchantId'] = data['merchantId']?.toString() ?? '';
          data['branchId'] = data['branchId']?.toString() ?? 'main';
          data['changeQuantity'] = double.tryParse(data['changeQuantity']?.toString() ?? '0') ?? 0.0;
          data['previousQuantity'] = double.tryParse(data['previousQuantity']?.toString() ?? '0') ?? 0.0;
          data['newQuantity'] = double.tryParse(data['newQuantity']?.toString() ?? '0') ?? 0.0;
          if (data['date'] == null) data['date'] = Timestamp.now();
          return InventoryLog.fromJson(data);
        } catch (e) {
          debugPrint('Error parsing InventoryLog ${snapshot.id}: $e');
          return null;
        }
      },
      toFirestore: (log, _) => log?.toJson() ?? {},
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id != 'store_profile_doc' && !doc.id.startsWith('counter_') && !doc.id.startsWith('act_'))
          .map((doc) => doc.data())
          .where((log) => log != null && log!.branchId == branchId)
          .cast<InventoryLog>()
          .toList();
    });
  }

  Future<void> logChange({
    required String productId,
    required String productName,
    required num previousQuantity,
    required num newQuantity,
    required String reason,
    String branchId = 'main',
    String? userEmail,
    String? userName,
    String? itemType,
  }) async {
    final change = (newQuantity - previousQuantity).toDouble();
    if (change == 0) return;

    final log = InventoryLog(
      id: Uuid().v4(),
      merchantId: _merchantId,
      branchId: branchId,
      productId: productId,
      productName: productName,
      changeQuantity: change,
      previousQuantity: previousQuantity.toDouble(),
      newQuantity: newQuantity.toDouble(),
      reason: reason,
      userEmail: userEmail,
      userName: userName,
      itemType: itemType,
      date: DateTime.now(),
    );
    await _logsRef.doc(log.id).set(log.toJson());
  }

  Future<void> revertLog(
    InventoryLog log, {
    required String userEmail,
    required String userName,
  }) async {
    if (log.isReverted) return;

    final branchRepo = BranchInventoryRepository(_firestore, _merchantId);
    final type = log.itemType == 'raw_material' ? 'raw_material' : 'product';
    double legacyMainQuantity = 0.0;
    if (log.branchId == 'main') {
      final collection = type == 'raw_material' ? 'raw_materials' : 'products';
      final legacy = await _firestore.collection(collection).doc(log.productId).get(const GetOptions(source: Source.serverAndCache));
      legacyMainQuantity = (legacy.data()?['quantity'] as num?)?.toDouble() ?? log.newQuantity;
    }

    // Reverse the inventory effect first. The branch repository enforces
    // non-negative inventory and serializes concurrent corrections.
    final newQuantity = await branchRepo.changeQuantity(
      branchId: log.branchId,
      itemType: type,
      itemId: log.productId,
      delta: -log.changeQuantity,
      legacyMainQuantity: legacyMainQuantity,
    );

    final batch = _firestore.batch();
    batch.update(_logsRef.doc(log.id), {'isReverted': true});
    final revertRef = _logsRef.doc(const Uuid().v4());
    batch.set(revertRef, InventoryLog(
      id: revertRef.id,
      merchantId: _merchantId,
      branchId: log.branchId,
      productId: log.productId,
      productName: log.productName,
      changeQuantity: -log.changeQuantity,
      previousQuantity: newQuantity + log.changeQuantity,
      newQuantity: newQuantity,
      reason: 'تراجع عن عملية سابقة / Reverted previous log',
      userEmail: userEmail,
      userName: userName,
      itemType: log.itemType,
      date: DateTime.now(),
    ).toJson());

    try {
      await batch.commit();
    } catch (_) {
      // Put inventory back if ledger commit fails; never leave a silent stock
      // mutation without its audit trail.
      await branchRepo.changeQuantity(
        branchId: log.branchId,
        itemType: type,
        itemId: log.productId,
        delta: log.changeQuantity,
        legacyMainQuantity: legacyMainQuantity,
      );
      rethrow;
    }
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
  final branchId = ref.watch(selectedBranchIdProvider);
  return repo.watchLogs(branchId: branchId);
});

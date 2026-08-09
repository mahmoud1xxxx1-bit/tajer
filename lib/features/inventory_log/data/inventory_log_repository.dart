import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/inventory_log.dart';

class InventoryLogRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;
  final String _branchId;

  InventoryLogRepository(this._firestore, this._merchantId, this._branchId);

  CollectionReference<Map<String, dynamic>> get _logsRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('inventory_logs');

  Stream<List<InventoryLog>> watchLogs({String? branchId}) {
    final scope = branchId ?? _branchId;
    return _logsRef
        .where('branchId', isEqualTo: scope)
        .orderBy('date', descending: true)
        .withConverter<InventoryLog?>(
          fromFirestore: (snapshot, _) {
            try {
              final data = Map<String, dynamic>.from(snapshot.data() ?? {});
              data['id'] = snapshot.id;
              data['productId'] = data['productId']?.toString() ?? '';
              data['productName'] = data['productName']?.toString() ?? '';
              data['reason'] = data['reason']?.toString() ?? '';
              data['merchantId'] = data['merchantId']?.toString() ?? '';
              data['branchId'] = data['branchId']?.toString() ?? 'main';
              data['changeQuantity'] =
                  double.tryParse(data['changeQuantity']?.toString() ?? '0') ??
                      0.0;
              data['previousQuantity'] = double.tryParse(
                      data['previousQuantity']?.toString() ?? '0') ??
                  0.0;
              data['newQuantity'] =
                  double.tryParse(data['newQuantity']?.toString() ?? '0') ??
                      0.0;
              if (data['date'] == null) data['date'] = Timestamp.now();
              return InventoryLog.fromJson(data);
            } catch (e) {
              debugPrint('Error parsing InventoryLog ${snapshot.id}: $e');
              return null;
            }
          },
          toFirestore: (log, _) => log?.toJson() ?? {},
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) =>
              doc.id != 'store_profile_doc' &&
              !doc.id.startsWith('counter_') &&
              !doc.id.startsWith('act_'))
          .map((doc) => doc.data())
          .where((log) => log != null && log!.branchId == scope)
          .cast<InventoryLog>()
          .toList();
    });
  }

  /// Canonical manual stock-count path. The branch quantity and its audit log
  /// commit together so there is never a silent manual mutation.
  Future<void> logChange({
    required String productId,
    required String productName,
    required num previousQuantity,
    required num newQuantity,
    required String reason,
    String? branchId,
    String? userEmail,
    String? userName,
    String? itemType,
  }) async {
    final previous = previousQuantity.toDouble();
    final next = newQuantity.toDouble();
    if ((next - previous).abs() <= 0.000001) return;

    final scope = branchId ?? _branchId;
    final type = itemType == 'raw_material' ? 'raw_material' : 'product';
    final branchRepo = BranchInventoryRepository(_firestore, _merchantId);

    await branchRepo.setQuantityWithAudit(
      branchId: scope,
      itemType: type,
      itemId: productId,
      itemName: productName,
      quantity: next,
      legacyMainQuantity: scope == 'main' ? previous : 0.0,
      reason: reason,
      userEmail: userEmail,
      userName: userName,
    );
  }

  /// Reverts an audit entry with optimistic ownership and a single Firestore
  /// transaction: current branch stock, original-log state and reversal log are
  /// committed together. Two devices cannot revert the same entry twice.
  Future<void> revertLog(
    InventoryLog log, {
    required String userEmail,
    required String userName,
  }) async {
    final branchRepo = BranchInventoryRepository(_firestore, _merchantId);
    final type = log.itemType == 'raw_material' ? 'raw_material' : 'product';
    final inventoryId = branchRepo.docId(log.branchId, type, log.productId);
    final inventoryRef = branchRepo.ref.doc(inventoryId);
    final originalLogRef = _logsRef.doc(log.id);
    final reversalRef = _logsRef.doc(const Uuid().v4());

    double legacyMainQuantity = 0.0;
    if (log.branchId == 'main') {
      final collection = type == 'raw_material' ? 'raw_materials' : 'products';
      final legacy = await _firestore
          .collection(collection)
          .doc(log.productId)
          .get(const GetOptions(source: Source.serverAndCache));
      legacyMainQuantity =
          (legacy.data()?['quantity'] as num?)?.toDouble() ?? log.newQuantity;
    }

    await _firestore.runTransaction<void>((tx) async {
      final originalSnap = await tx.get(originalLogRef);
      if (!originalSnap.exists) {
        throw Exception('Inventory log not found');
      }
      if (originalSnap.data()?['isReverted'] == true) return;

      final inventorySnap = await tx.get(inventoryRef);
      final current = inventorySnap.exists
          ? (inventorySnap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
          : (log.branchId == 'main' ? legacyMainQuantity : 0.0);
      final next = current - log.changeQuantity;
      if (next < -0.000001) {
        throw Exception(
            'Cannot revert: branch inventory would become negative');
      }
      final normalized = next < 0 ? 0.0 : next;
      final initial = inventorySnap.exists
          ? ((inventorySnap.data()?['initialQuantity'] as num?)?.toDouble() ??
              current)
          : current;

      tx.set(
        inventoryRef,
        {
          'id': inventoryId,
          'merchantId': _merchantId,
          'branchId': log.branchId,
          'itemId': log.productId,
          'itemType': type,
          'quantity': normalized,
          'initialQuantity': initial,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.update(originalLogRef, {
        'isReverted': true,
        'revertedAt': FieldValue.serverTimestamp(),
        'revertedBy': userName,
      });

      tx.set(reversalRef, {
        'id': reversalRef.id,
        'merchantId': _merchantId,
        'branchId': log.branchId,
        'productId': log.productId,
        'productName': log.productName,
        'changeQuantity': -log.changeQuantity,
        'previousQuantity': current,
        'newQuantity': normalized,
        'reason': 'تراجع عن عملية سابقة / Reverted previous log',
        'userEmail': userEmail,
        'userName': userName,
        'itemType': type,
        'date': FieldValue.serverTimestamp(),
        'isReverted': false,
        'revertsLogId': log.id,
      });
    });
  }
}

final inventoryLogRepositoryProvider = Provider<InventoryLogRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  final branchId = ref.watch(selectedBranchIdProvider);
  return InventoryLogRepository(
    FirebaseFirestore.instance,
    currentEffectiveMerchantId(appUser),
    branchId,
  );
});

final inventoryLogsStreamProvider = StreamProvider<List<InventoryLog>>((ref) {
  final repo = ref.watch(inventoryLogRepositoryProvider);
  if (repo == null) return Stream.value([]);
  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return Stream.value([]);
  return repo.watchLogs(branchId: branchId);
});

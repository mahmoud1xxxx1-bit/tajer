import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/branch_inventory.dart';
import '../domain/inventory_transfer.dart';

class BranchInventoryMutation {
  final String itemType;
  final String itemId;
  final double delta;
  final double legacyMainQuantity;

  const BranchInventoryMutation({
    required this.itemType,
    required this.itemId,
    required this.delta,
    required this.legacyMainQuantity,
  });
}

class BranchInventoryRepository {
  final FirebaseFirestore firestore;
  final String merchantId;

  BranchInventoryRepository(this.firestore, this.merchantId);

  CollectionReference<Map<String, dynamic>> get ref => firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('branch_inventory');

  CollectionReference<Map<String, dynamic>> get _logsRef => firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('inventory_logs');

  CollectionReference<Map<String, dynamic>> get _transfersRef => firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('inventory_transfers');

  String docId(String branchId, String itemType, String itemId) =>
      '${branchId}_${itemType}_$itemId';

  Stream<List<BranchInventory>> watch(String branchId) {
    return ref.where('branchId', isEqualTo: branchId).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return BranchInventory.fromJson(data);
          }).toList(),
        );
  }

  Stream<List<InventoryTransfer>> watchTransfers() {
    return _transfersRef.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return InventoryTransfer.fromJson(data);
          }).toList(),
        );
  }

  Future<BranchInventory?> getItem({
    required String branchId,
    required String itemType,
    required String itemId,
  }) async {
    final doc = await ref.doc(docId(branchId, itemType, itemId)).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return BranchInventory.fromJson(data);
  }

  Future<void> setQuantity({
    required String branchId,
    required String itemType,
    required String itemId,
    required double quantity,
    required double initialQuantity,
  }) async {
    if (quantity < 0) throw Exception('Branch inventory cannot be negative');
    final id = docId(branchId, itemType, itemId);
    await ref.doc(id).set({
      'id': id,
      'merchantId': merchantId,
      'branchId': branchId,
      'itemId': itemId,
      'itemType': itemType,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<double> setQuantityWithAudit({
    required String branchId,
    required String itemType,
    required String itemId,
    required String itemName,
    required double quantity,
    required double legacyMainQuantity,
    required String reason,
    String? userEmail,
    String? userName,
  }) async {
    if (quantity < -0.000001)
      throw Exception('Branch inventory cannot be negative');
    final normalizedQuantity = quantity < 0 ? 0.0 : quantity;
    final id = docId(branchId, itemType, itemId);
    final inventoryRef = ref.doc(id);
    final logRef = _logsRef.doc();

    return firestore.runTransaction<double>((tx) async {
      final snap = await tx.get(inventoryRef);
      final current = snap.exists
          ? (snap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
          : (branchId == 'main' ? legacyMainQuantity : 0.0);
      if ((normalizedQuantity - current).abs() <= 0.000001) return current;
      final initial = snap.exists
          ? ((snap.data()?['initialQuantity'] as num?)?.toDouble() ?? current)
          : current;
      tx.set(
          inventoryRef,
          {
            'id': id,
            'merchantId': merchantId,
            'branchId': branchId,
            'itemId': itemId,
            'itemType': itemType,
            'quantity': normalizedQuantity,
            'initialQuantity':
                initial == 0.0 && current == 0.0 ? normalizedQuantity : initial,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      tx.set(logRef, {
        'id': logRef.id,
        'merchantId': merchantId,
        'branchId': branchId,
        'productId': itemId,
        'productName': itemName,
        'itemType': itemType,
        'changeQuantity': normalizedQuantity - current,
        'previousQuantity': current,
        'newQuantity': normalizedQuantity,
        'reason': reason,
        'date': FieldValue.serverTimestamp(),
        'userEmail': userEmail,
        'userName': userName,
        'isReverted': false,
      });
      return normalizedQuantity;
    });
  }

  Future<String> transferQuantity({
    required String fromBranchId,
    required String toBranchId,
    required String itemType,
    required String itemId,
    String? destinationItemId,
    String? operationId,
    required String itemName,
    required double quantity,
    double legacySourceMainQuantity = 0.0,
    double legacyDestinationMainQuantity = 0.0,
    String? userEmail,
    String? userName,
    String? note,
  }) async {
    if (fromBranchId == toBranchId)
      throw Exception('Source and destination branches must be different');
    if (quantity <= 0.000001)
      throw Exception('Transfer quantity must be greater than zero');
    if (itemType != 'product' && itemType != 'raw_material')
      throw Exception('Unsupported inventory item type');

    final toItemId = destinationItemId?.trim().isNotEmpty == true
        ? destinationItemId!.trim()
        : itemId;
    final fromId = docId(fromBranchId, itemType, itemId);
    final toId = docId(toBranchId, itemType, toItemId);
    final fromRef = ref.doc(fromId);
    final toRef = ref.doc(toId);
    final transferRef = operationId?.trim().isNotEmpty == true
        ? _transfersRef.doc(operationId!.trim())
        : _transfersRef.doc();
    final sourceLogRef = _logsRef.doc();
    final destinationLogRef = _logsRef.doc();

    await firestore.runTransaction<void>((tx) async {
      final existingTransfer = await tx.get(transferRef);
      if (existingTransfer.exists) return;
      final fromSnap = await tx.get(fromRef);
      final toSnap = await tx.get(toRef);
      final fromCurrent = fromSnap.exists
          ? (fromSnap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
          : (fromBranchId == 'main' ? legacySourceMainQuantity : 0.0);
      final toCurrent = toSnap.exists
          ? (toSnap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
          : (toBranchId == 'main' ? legacyDestinationMainQuantity : 0.0);
      final fromNext = fromCurrent - quantity;
      if (fromNext < -0.000001)
        throw Exception('Insufficient source branch inventory');
      final normalizedFromNext = fromNext < 0 ? 0.0 : fromNext;
      final toNext = toCurrent + quantity;
      final fromInitial = fromSnap.exists
          ? ((fromSnap.data()?['initialQuantity'] as num?)?.toDouble() ??
              fromCurrent)
          : fromCurrent;
      final toInitial = toSnap.exists
          ? ((toSnap.data()?['initialQuantity'] as num?)?.toDouble() ??
              toCurrent)
          : toCurrent;

      tx.set(
          fromRef,
          {
            'id': fromId,
            'merchantId': merchantId,
            'branchId': fromBranchId,
            'itemId': itemId,
            'itemType': itemType,
            'quantity': normalizedFromNext,
            'initialQuantity': fromInitial,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      tx.set(
          toRef,
          {
            'id': toId,
            'merchantId': merchantId,
            'branchId': toBranchId,
            'itemId': toItemId,
            'itemType': itemType,
            'quantity': toNext,
            'initialQuantity': toSnap.exists ? toInitial : toNext,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      tx.set(sourceLogRef, {
        'id': sourceLogRef.id,
        'merchantId': merchantId,
        'branchId': fromBranchId,
        'productId': itemId,
        'productName': itemName,
        'itemType': itemType,
        'changeQuantity': -quantity,
        'previousQuantity': fromCurrent,
        'newQuantity': normalizedFromNext,
        'reason':
            'تحويل مخزون إلى فرع $toBranchId / Stock transfer to $toBranchId',
        'date': FieldValue.serverTimestamp(),
        'userEmail': userEmail,
        'userName': userName,
        'isReverted': false,
        'transferId': transferRef.id,
      });
      tx.set(destinationLogRef, {
        'id': destinationLogRef.id,
        'merchantId': merchantId,
        'branchId': toBranchId,
        'productId': toItemId,
        'productName': itemName,
        'itemType': itemType,
        'changeQuantity': quantity,
        'previousQuantity': toCurrent,
        'newQuantity': toNext,
        'reason':
            'تحويل مخزون من فرع $fromBranchId / Stock transfer from $fromBranchId',
        'date': FieldValue.serverTimestamp(),
        'userEmail': userEmail,
        'userName': userName,
        'isReverted': false,
        'transferId': transferRef.id,
      });
      tx.set(transferRef, {
        'id': transferRef.id,
        'merchantId': merchantId,
        'fromBranchId': fromBranchId,
        'toBranchId': toBranchId,
        'sourceItemId': itemId,
        'destinationItemId': toItemId,
        'itemId': itemId,
        'itemName': itemName,
        'itemType': itemType,
        'quantity': quantity,
        'sourceQuantityBefore': fromCurrent,
        'sourceQuantityAfter': normalizedFromNext,
        'destinationQuantityBefore': toCurrent,
        'destinationQuantityAfter': toNext,
        'status': 'completed',
        'note': note,
        'createdByEmail': userEmail,
        'createdByName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return transferRef.id;
  }

  Future<double> changeQuantity({
    required String branchId,
    required String itemType,
    required String itemId,
    required double delta,
    required double legacyMainQuantity,
  }) async {
    final result = await changeQuantities(
      branchId: branchId,
      mutations: [
        BranchInventoryMutation(
            itemType: itemType,
            itemId: itemId,
            delta: delta,
            legacyMainQuantity: legacyMainQuantity)
      ],
    );
    return result[docId(branchId, itemType, itemId)]!;
  }

  Future<Map<String, double>> changeQuantities({
    required String branchId,
    required List<BranchInventoryMutation> mutations,
  }) async {
    if (mutations.isEmpty) return const {};
    final merged = <String, BranchInventoryMutation>{};
    for (final mutation in mutations) {
      final key = docId(branchId, mutation.itemType, mutation.itemId);
      final existing = merged[key];
      merged[key] = existing == null
          ? mutation
          : BranchInventoryMutation(
              itemType: mutation.itemType,
              itemId: mutation.itemId,
              delta: existing.delta + mutation.delta,
              legacyMainQuantity: mutation.legacyMainQuantity);
    }
    return firestore.runTransaction<Map<String, double>>((tx) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in merged.entries) {
        snapshots[entry.key] = await tx.get(ref.doc(entry.key));
      }
      final nextQuantities = <String, double>{};
      for (final entry in merged.entries) {
        final mutation = entry.value;
        final snap = snapshots[entry.key]!;
        final current = snap.exists
            ? (snap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
            : (branchId == 'main' ? mutation.legacyMainQuantity : 0.0);
        final next = current + mutation.delta;
        if (next < -0.000001)
          throw Exception('Insufficient branch inventory: ${mutation.itemId}');
        nextQuantities[entry.key] = next < 0 ? 0.0 : next;
      }
      for (final entry in merged.entries) {
        final mutation = entry.value;
        final snap = snapshots[entry.key]!;
        final current = snap.exists
            ? (snap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
            : (branchId == 'main' ? mutation.legacyMainQuantity : 0.0);
        tx.set(
            ref.doc(entry.key),
            {
              'id': entry.key,
              'merchantId': merchantId,
              'branchId': branchId,
              'itemId': mutation.itemId,
              'itemType': mutation.itemType,
              'quantity': nextQuantities[entry.key],
              'initialQuantity': snap.exists
                  ? ((snap.data()?['initialQuantity'] as num?)?.toDouble() ??
                      current)
                  : current,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
      return nextQuantities;
    });
  }
}

final branchInventoryRepositoryProvider =
    Provider<BranchInventoryRepository?>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return null;
  return BranchInventoryRepository(
      FirebaseFirestore.instance, currentEffectiveMerchantId(user));
});

final branchInventoryStreamProvider =
    StreamProvider.family<List<BranchInventory>, String>((ref, branchId) {
  final repository = ref.watch(branchInventoryRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  if (branchId.isEmpty) return Stream.value(const []);
  return repository.watch(branchId);
});

final inventoryTransfersStreamProvider =
    StreamProvider<List<InventoryTransfer>>((ref) {
  final repository = ref.watch(branchInventoryRepositoryProvider);
  final appUser = ref.watch(appUserProvider).value;
  if (repository == null) return Stream.value(const <InventoryTransfer>[]);
  if (appUser?.role == 'employee') {
    return Stream.value(const <InventoryTransfer>[]);
  }
  return repository.watchTransfers();
});

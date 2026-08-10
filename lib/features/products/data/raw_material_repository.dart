import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/raw_material.dart';

class RawMaterialRepository {
  final FirebaseFirestore _firestore;

  RawMaterialRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _availabilityRef(
    String merchantId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('raw_material_branch_availability');

  String availabilityDocId(String branchId, String rawMaterialId) =>
      '${branchId}_$rawMaterialId';

  Stream<Map<String, bool>> watchAvailability(
      String merchantId, String branchId) {
    return _availabilityRef(merchantId)
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map((snapshot) {
      return {
        for (final doc in snapshot.docs)
          '${doc.data()['rawMaterialId']}::${doc.data()['branchId']}':
              doc.data()['enabled'] == true,
      };
    });
  }

  Future<void> setRawMaterialAvailability({
    required BranchOperationContext context,
    required String rawMaterialId,
    required Set<String> enabledBranchIds,
    Set<String> knownBranchIds = const <String>{},
  }) async {
    if (!context.isValid) throw StateError('Invalid branch operation context');
    final existing = await _availabilityRef(context.merchantId)
        .where('rawMaterialId', isEqualTo: rawMaterialId)
        .get();
    final allBranchIds = <String>{
      ...knownBranchIds,
      ...enabledBranchIds,
      for (final doc in existing.docs) doc.data()['branchId']?.toString() ?? '',
    }..removeWhere((branchId) => branchId.isEmpty);

    final batch = _firestore.batch();
    for (final branchId in allBranchIds) {
      final ref = _availabilityRef(context.merchantId)
          .doc(availabilityDocId(branchId, rawMaterialId));
      batch.set(
          ref,
          {
            'id': ref.id,
            'merchantId': context.merchantId,
            'branchId': branchId,
            'rawMaterialId': rawMaterialId,
            'enabled': enabledBranchIds.contains(branchId),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<bool> isAvailableInBranch({
    required String merchantId,
    required String rawMaterialId,
    required String branchId,
  }) async {
    final explicit = await _availabilityRef(merchantId)
        .doc(availabilityDocId(branchId, rawMaterialId))
        .get();
    if (explicit.exists) return explicit.data()?['enabled'] == true;

    final anyExplicit = await _availabilityRef(merchantId)
        .where('rawMaterialId', isEqualTo: rawMaterialId)
        .limit(1)
        .get();
    if (anyExplicit.docs.isNotEmpty) return false;
    if (branchId == 'main') return true;

    final inventoryId = '${branchId}_raw_material_$rawMaterialId';
    final inventory = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc(inventoryId)
        .get();
    return inventory.exists;
  }

  Stream<List<RawMaterial>> watchRawMaterials(String merchantId) {
    return _firestore
        .collection('raw_materials')
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map((doc) => RawMaterial.fromJson(doc.data())).toList();
      return items.where((item) => !item.isArchived).toList();
    });
  }

  /// Raw-material documents are merchant-wide master data. Stock belongs to
  /// branch_inventory, so a newly-created item starts with zero legacy stock.
  Future<void> addRawMaterial(
    RawMaterial rawMaterial, {
    required BranchOperationContext context,
    required Set<String> enabledBranchIds,
    Set<String> knownBranchIds = const <String>{},
  }) async {
    if (rawMaterial.merchantId != context.merchantId) {
      throw StateError('Raw material merchant mismatch');
    }
    final data = rawMaterial.toJson();
    data['quantity'] = 0.0;
    data['initialQuantity'] = 0.0;
    final batch = _firestore.batch();
    batch.set(_firestore.collection('raw_materials').doc(rawMaterial.id), data);
    final branchesToWrite = <String>{...knownBranchIds, ...enabledBranchIds}
      ..removeWhere((branchId) => branchId.isEmpty);
    for (final branchId in branchesToWrite) {
      final ref = _availabilityRef(rawMaterial.merchantId)
          .doc(availabilityDocId(branchId, rawMaterial.id));
      batch.set(ref, {
        'id': ref.id,
        'merchantId': rawMaterial.merchantId,
        'branchId': branchId,
        'rawMaterialId': rawMaterial.id,
        'enabled': enabledBranchIds.contains(branchId),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Do not overwrite merchant-wide legacy stock with the currently selected
  /// branch quantity. Stock corrections are applied via BranchInventoryRepository.
  Future<void> updateRawMaterial(RawMaterial rawMaterial) async {
    final data = rawMaterial.toJson();
    data.remove('quantity');
    data.remove('initialQuantity');
    await _firestore
        .collection('raw_materials')
        .doc(rawMaterial.id)
        .update(data);
  }

  Future<void> deleteRawMaterial(String id) async {
    await _firestore
        .collection('raw_materials')
        .doc(id)
        .update({'isArchived': true});
  }
}

final rawMaterialRepositoryProvider = Provider<RawMaterialRepository>((ref) {
  return RawMaterialRepository(FirebaseFirestore.instance);
});

final rawMaterialsStreamProvider =
    StreamProvider.family<List<RawMaterial>, String>((ref, merchantId) {
  final repository = ref.watch(rawMaterialRepositoryProvider);
  final branchId = ref.watch(selectedBranchIdProvider);
  final branchInventory = ref.watch(branchInventoryStreamProvider(branchId));
  final availabilityStream = repository.watchAvailability(merchantId, branchId);

  return repository.watchRawMaterials(merchantId).asyncExpand((materials) {
    return availabilityStream.map((availability) {
      final inventory = branchInventory.valueOrNull ?? const [];
      final scoped = {
        for (final item in inventory)
          if (item.itemType == 'raw_material') item.itemId: item,
      };
      return materials.where((material) {
        final key = '${material.id}::$branchId';
        final enabled = availability[key];
        if (enabled != null) return enabled;
        return branchId == 'main' || scoped.containsKey(material.id);
      }).map((material) {
        final item = scoped[material.id];
        if (item != null) {
          return material.copyWith(
            quantity: item.quantity,
            initialQuantity: item.initialQuantity,
          );
        }
        if (branchId == 'main') return material;
        return material.copyWith(quantity: 0.0, initialQuantity: 0.0);
      }).toList();
    });
  });
});

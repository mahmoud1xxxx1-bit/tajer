import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/raw_material.dart';

class RawMaterialRepository {
  final FirebaseFirestore _firestore;

  RawMaterialRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _branchRawMaterialsRef(
    String merchantId,
    String branchId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .collection('raw_materials');

  DocumentReference<Map<String, dynamic>> _branchRawMaterialRef(
    String merchantId,
    String branchId,
    String rawMaterialId,
  ) =>
      _branchRawMaterialsRef(merchantId, branchId).doc(rawMaterialId);

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

  Future<bool> existsInBranch({
    required String merchantId,
    required String rawMaterialId,
    required String branchId,
  }) async {
    final doc =
        await _branchRawMaterialRef(merchantId, branchId, rawMaterialId).get();
    return doc.exists && doc.data()?['isArchived'] != true;
  }

  Stream<List<RawMaterial>> watchRawMaterials(
    String merchantId,
    String branchId,
  ) {
    return _branchRawMaterialsRef(merchantId, branchId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['merchantId'] = data['merchantId']?.toString() ?? merchantId;
        data['branchId'] = data['branchId']?.toString() ?? branchId;
        return RawMaterial.fromJson(data);
      }).toList();
      return items.where((item) => !item.isArchived).toList();
    });
  }

  Future<void> migrateBranchRawMaterialsIfNeeded({
    required String merchantId,
    required String branchId,
  }) async {
    final stateRef = _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('migration_state')
        .doc('branch_raw_materials_v1_$branchId');
    final state = await stateRef.get();
    if (state.data()?['status'] == 'completed') return;

    final legacyMaterials = await _firestore
        .collection('raw_materials')
        .where('merchantId', isEqualTo: merchantId)
        .get();
    final availability = await _availabilityRef(merchantId).get();
    final inventory = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .where('branchId', isEqualTo: branchId)
        .where('itemType', isEqualTo: 'raw_material')
        .get();

    final explicit = <String, bool>{};
    final anyExplicit = <String>{};
    for (final doc in availability.docs) {
      final data = doc.data();
      final rawMaterialId = data['rawMaterialId']?.toString();
      final availabilityBranchId = data['branchId']?.toString();
      if (rawMaterialId == null || rawMaterialId.isEmpty) continue;
      anyExplicit.add(rawMaterialId);
      if (availabilityBranchId == branchId) {
        explicit[rawMaterialId] = data['enabled'] == true;
      }
    }
    final inventoryEvidence = {
      for (final doc in inventory.docs) doc.data()['itemId']?.toString() ?? '',
    }..remove('');

    final batch = _firestore.batch();
    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': branchId,
          'startedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    var writes = 1;
    for (final doc in legacyMaterials.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final rawMaterialId = doc.id;
      final enabled = explicit[rawMaterialId];
      final belongsToBranch = enabled ??
          (anyExplicit.contains(rawMaterialId)
              ? false
              : (inventoryEvidence.contains(rawMaterialId) ||
                  branchId == 'main'));
      if (!belongsToBranch) continue;
      data['id'] = rawMaterialId;
      data['merchantId'] = merchantId;
      data['branchId'] = branchId;
      data['quantity'] = 0.0;
      data['initialQuantity'] = 0.0;
      batch.set(
        _branchRawMaterialRef(merchantId, branchId, rawMaterialId),
        data,
        SetOptions(merge: true),
      );
      writes++;
      if (writes >= 450) break;
    }

    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'completed',
          'branchId': branchId,
          'completedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
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
    data['branchId'] = context.branchId;
    batch.set(
      _branchRawMaterialRef(
          context.merchantId, context.branchId, rawMaterial.id),
      data,
    );
    await batch.commit();
  }

  /// Do not overwrite merchant-wide legacy stock with the currently selected
  /// branch quantity. Stock corrections are applied via BranchInventoryRepository.
  Future<void> updateRawMaterial(
    RawMaterial rawMaterial, {
    required BranchOperationContext context,
  }) async {
    final data = rawMaterial.toJson();
    data.remove('quantity');
    data.remove('initialQuantity');
    data['branchId'] = context.branchId;
    await _branchRawMaterialRef(
            context.merchantId, context.branchId, rawMaterial.id)
        .update(data);
  }

  Future<void> deleteRawMaterial({
    required BranchOperationContext context,
    required String id,
  }) async {
    await _branchRawMaterialRef(context.merchantId, context.branchId, id)
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
  repository
      .migrateBranchRawMaterialsIfNeeded(
          merchantId: merchantId, branchId: branchId)
      .catchError((_) {});

  return repository.watchRawMaterials(merchantId, branchId).map((materials) {
    final inventory = branchInventory.valueOrNull ?? const [];
    final scoped = {
      for (final item in inventory)
        if (item.itemType == 'raw_material') item.itemId: item,
    };
    return materials.map((material) {
      final item = scoped[material.id];
      if (item != null) {
        return material.copyWith(
          quantity: item.quantity,
          initialQuantity: item.initialQuantity,
        );
      }
      return material.copyWith(quantity: 0.0, initialQuantity: 0.0);
    }).toList();
  });
});

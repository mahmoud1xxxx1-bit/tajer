import '../../../core/services/entitlement_integration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/legacy_catalog_migration_normalizer.dart';
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

  CollectionReference<Map<String, dynamic>> _legacyVisibilityRef(
    String merchantId,
    String branchId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .collection('legacy_raw_material_visibility');

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

  DocumentReference<Map<String, dynamic>> _rawMigrationStateRef(
    String merchantId,
    String branchId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('branch_raw_materials_v1_$branchId');

  DocumentReference<Map<String, dynamic>> _rawVisibilityStateRef(
    String merchantId,
    String branchId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('legacy_raw_material_visibility_v1_$branchId');

  Future<bool> isBranchRawMaterialMigrationCompleted({
    required String merchantId,
    required String branchId,
  }) async {
    final state = await _rawMigrationStateRef(merchantId, branchId).get();
    return state.data()?['status'] == 'completed';
  }

  Future<void> migrateBranchRawMaterialsPage({
    required String merchantId,
    required String branchId,
    int pageSize = 400,
  }) async {
    final stateRef = _rawMigrationStateRef(merchantId, branchId);
    final state = await stateRef.get();
    if (state.data()?['status'] == 'completed') return;
    final lastLegacyRawMaterialId =
        state.data()?['lastLegacyRawMaterialId']?.toString();

    var query = _firestore
        .collection('raw_materials')
        .where('merchantId', isEqualTo: merchantId);
    if (lastLegacyRawMaterialId != null && lastLegacyRawMaterialId.isNotEmpty) {
      query = query.where(FieldPath.documentId,
          isGreaterThan: lastLegacyRawMaterialId);
    }
    final effectivePageSize = pageSize > 240 ? 240 : pageSize;
    query = query.orderBy(FieldPath.documentId).limit(effectivePageSize);
    final legacyMaterials = await query.get();
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

    if (legacyMaterials.docs.isEmpty) {
      await stateRef.set({
        'version': 1,
        'status': 'completed',
        'branchId': branchId,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final batch = _firestore.batch();
    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': branchId,
          'lastError': FieldValue.delete(),
          'startedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    var lastProcessedId = lastLegacyRawMaterialId;
    for (final doc in legacyMaterials.docs) {
      final rawMaterialId = doc.id;
      lastProcessedId = rawMaterialId;
      final enabled = explicit[rawMaterialId];
      final belongsToBranch = enabled ??
          (anyExplicit.contains(rawMaterialId)
              ? false
              : (inventoryEvidence.contains(rawMaterialId) ||
                  branchId == 'main'));
      if (!belongsToBranch) continue;
      final data = normalizeLegacyRawMaterialForBranch(
        document: doc,
        merchantId: merchantId,
        branchId: branchId,
      );
      batch.set(
        _branchRawMaterialRef(merchantId, branchId, rawMaterialId),
        data,
        SetOptions(merge: true),
      );
      batch.set(
        _legacyVisibilityRef(merchantId, branchId).doc(rawMaterialId),
        {
          'id': rawMaterialId,
          'merchantId': merchantId,
          'branchId': branchId,
          'rawMaterialId': rawMaterialId,
          'enabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': branchId,
          'lastLegacyRawMaterialId': lastProcessedId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> migrateBranchRawMaterialsIfNeeded({
    required String merchantId,
    required String branchId,
    int pageSize = 400,
  }) async {
    for (var i = 0; i < 1000; i++) {
      await migrateBranchRawMaterialsPage(
        merchantId: merchantId,
        branchId: branchId,
        pageSize: pageSize,
      );
      if (await isBranchRawMaterialMigrationCompleted(
        merchantId: merchantId,
        branchId: branchId,
      )) {
        return;
      }
    }
    await _rawMigrationStateRef(merchantId, branchId).set({
      'version': 1,
      'status': 'failed',
      'branchId': branchId,
      'lastError': 'Raw material migration exceeded maximum page count',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    throw StateError('Raw material migration exceeded maximum page count');
  }

  Future<bool> isLegacyRawMaterialVisibilityManifestCompleted({
    required String merchantId,
    required String branchId,
  }) async {
    final state = await _rawVisibilityStateRef(merchantId, branchId).get();
    return state.data()?['status'] == 'completed';
  }

  Future<void> buildLegacyRawMaterialVisibilityManifestPage({
    required String merchantId,
    required String branchId,
    int pageSize = 400,
  }) async {
    final stateRef = _rawVisibilityStateRef(merchantId, branchId);
    final state = await stateRef.get();
    if (state.data()?['status'] == 'completed') return;
    final lastLegacyRawMaterialId =
        state.data()?['lastLegacyRawMaterialId']?.toString();

    var query = _firestore
        .collection('raw_materials')
        .where('merchantId', isEqualTo: merchantId);
    if (lastLegacyRawMaterialId != null && lastLegacyRawMaterialId.isNotEmpty) {
      query = query.where(FieldPath.documentId,
          isGreaterThan: lastLegacyRawMaterialId);
    }
    query = query.orderBy(FieldPath.documentId).limit(pageSize);
    final legacyMaterials = await query.get();
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

    if (legacyMaterials.docs.isEmpty) {
      await stateRef.set({
        'version': 1,
        'status': 'completed',
        'branchId': branchId,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final batch = _firestore.batch();
    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': branchId,
          'lastError': FieldValue.delete(),
          'startedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    var lastProcessedId = lastLegacyRawMaterialId;
    for (final doc in legacyMaterials.docs) {
      final rawMaterialId = doc.id;
      lastProcessedId = rawMaterialId;
      final enabled = explicit[rawMaterialId];
      final belongsToBranch = enabled ??
          (anyExplicit.contains(rawMaterialId)
              ? false
              : (inventoryEvidence.contains(rawMaterialId) ||
                  branchId == 'main'));
      if (!belongsToBranch) continue;
      batch.set(
        _legacyVisibilityRef(merchantId, branchId).doc(rawMaterialId),
        {
          'id': rawMaterialId,
          'merchantId': merchantId,
          'branchId': branchId,
          'rawMaterialId': rawMaterialId,
          'enabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': branchId,
          'lastLegacyRawMaterialId': lastProcessedId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> buildLegacyRawMaterialVisibilityManifestIfNeeded({
    required String merchantId,
    required String branchId,
    int pageSize = 400,
  }) async {
    for (var i = 0; i < 1000; i++) {
      await buildLegacyRawMaterialVisibilityManifestPage(
        merchantId: merchantId,
        branchId: branchId,
        pageSize: pageSize,
      );
      if (await isLegacyRawMaterialVisibilityManifestCompleted(
        merchantId: merchantId,
        branchId: branchId,
      )) {
        return;
      }
    }
    await _rawVisibilityStateRef(merchantId, branchId).set({
      'version': 1,
      'status': 'failed',
      'branchId': branchId,
      'lastError':
          'Raw material visibility manifest exceeded maximum page count',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    throw StateError(
        'Raw material visibility manifest exceeded maximum page count');
  }

  Future<List<RawMaterial>> readLegacyRawMaterialsForBranch({
    required String merchantId,
    required String branchId,
  }) async {
    if (!await isLegacyRawMaterialVisibilityManifestCompleted(
      merchantId: merchantId,
      branchId: branchId,
    )) {
      throw StateError(
          'Branch raw material compatibility manifest is not ready');
    }
    final visibility = await _legacyVisibilityRef(merchantId, branchId)
        .where('enabled', isEqualTo: true)
        .get();
    final materialIds = visibility.docs
        .map((doc) => doc.data()['rawMaterialId']?.toString() ?? doc.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final materials = <RawMaterial>[];
    for (final rawMaterialId in materialIds) {
      final doc =
          await _firestore.collection('raw_materials').doc(rawMaterialId).get();
      if (!doc.exists || doc.data() == null) continue;
      if (doc.data()?['merchantId']?.toString() != merchantId) continue;
      if (doc.data()?['isArchived'] == true) continue;
      final data = normalizeLegacyRawMaterialForBranch(
        document: doc,
        merchantId: merchantId,
        branchId: branchId,
      );
      materials.add(RawMaterial.fromJson(data));
    }
    return materials;
  }

  /// Raw-material documents are branch-owned catalog data. Stock belongs to
  /// branch_inventory, so a newly-created item starts with zero stock.
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
    await EntitlementIntegration.checkAndConsumeQuota(
      firestore: _firestore,
      merchantId: context.merchantId,
      branchId: context.branchId,
      resourceType: 'raw_materials',
      plan: null,
      batch: batch,
    );

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

  return repository.watchRawMaterials(merchantId, branchId).asyncExpand((materials) async* {
    var baseMaterials = materials;
    final migrationCompleted =
        await repository.isBranchRawMaterialMigrationCompleted(
      merchantId: merchantId,
      branchId: branchId,
    );
    if (!migrationCompleted) {
      baseMaterials = await repository.readLegacyRawMaterialsForBranch(
        merchantId: merchantId,
        branchId: branchId,
      );
    }
    
    // Explicitly await the future of the inventory provider to guarantee readiness.
    // This removes the "False Zero" glitch caused by AsyncLoading mapping to 0.
    final inventory = await ref.watch(branchInventoryStreamProvider(branchId).future);
    
    final scoped = {
      for (final item in inventory)
        if (item.itemType == 'raw_material') item.itemId: item,
    };
    yield baseMaterials.map((material) {
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/raw_material.dart';

class RawMaterialRepository {
  final FirebaseFirestore _firestore;

  RawMaterialRepository(this._firestore);

  Stream<List<RawMaterial>> watchRawMaterials(String merchantId) {
    return _firestore
        .collection('raw_materials')
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) => RawMaterial.fromJson(doc.data())).toList();
      return items.where((item) => !item.isArchived).toList();
    });
  }

  Future<void> addRawMaterial(RawMaterial rawMaterial) async {
    await _firestore.collection('raw_materials').doc(rawMaterial.id).set(rawMaterial.toJson());
  }

  Future<void> updateRawMaterial(RawMaterial rawMaterial) async {
    await _firestore.collection('raw_materials').doc(rawMaterial.id).update(rawMaterial.toJson());
  }

  Future<void> deleteRawMaterial(String id) async {
    await _firestore.collection('raw_materials').doc(id).update({'isArchived': true});
  }
}

final rawMaterialRepositoryProvider = Provider<RawMaterialRepository>((ref) {
  return RawMaterialRepository(FirebaseFirestore.instance);
});

final rawMaterialsStreamProvider = StreamProvider.family<List<RawMaterial>, String>((ref, merchantId) {
  final repository = ref.watch(rawMaterialRepositoryProvider);
  final branchId = ref.watch(selectedBranchIdProvider);
  final branchInventory = ref.watch(branchInventoryStreamProvider(branchId));

  return repository.watchRawMaterials(merchantId).map((materials) {
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
      // Backward compatibility: legacy v107 stock belongs to Main Branch only.
      if (branchId == 'main') return material;
      return material.copyWith(quantity: 0.0, initialQuantity: 0.0);
    }).toList();
  });
});

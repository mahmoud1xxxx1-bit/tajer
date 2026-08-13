import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/raw_material.dart';

class RawMaterialRepository {
  final FirebaseFirestore _firestore;

  RawMaterialRepository(this._firestore);

  Stream<List<RawMaterial>> watchRawMaterials(String merchantId) {
    return _firestore
        .collection('raw_materials')
        .where('merchantId', isEqualTo: merchantId)
        .limit(1000)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) => RawMaterial.fromJson(doc.data())).toList();
      return items.where((item) => !item.isArchived).toList();
    });
  }

  Query<RawMaterial> queryRawMaterials(String merchantId) {
    return _firestore
        .collection('raw_materials')
        .where('merchantId', isEqualTo: merchantId)
        .where('isArchived', isEqualTo: false)
        .orderBy('name')
        .withConverter<RawMaterial>(
          fromFirestore: (snapshot, _) => RawMaterial.fromJson(snapshot.data()!),
          toFirestore: (rawMaterial, _) => rawMaterial.toJson(),
        );
  }

  Future<void> addRawMaterial(RawMaterial rawMaterial) async {
    await _firestore
        .collection('raw_materials')
        .doc(rawMaterial.id)
        .set(rawMaterial.toJson());
  }

  Future<void> updateRawMaterial(RawMaterial rawMaterial) async {
    await _firestore
        .collection('raw_materials')
        .doc(rawMaterial.id)
        .update(rawMaterial.toJson());
  }

  Future<void> deleteRawMaterial(String id) async {
    await _firestore.collection('raw_materials').doc(id).update({
      'isArchived': true,
    });
  }
}

final rawMaterialRepositoryProvider = Provider<RawMaterialRepository>((ref) {
  return RawMaterialRepository(FirebaseFirestore.instance);
});

final rawMaterialsStreamProvider = StreamProvider.family<List<RawMaterial>, String>((ref, merchantId) {
  final repository = ref.watch(rawMaterialRepositoryProvider);
  return repository.watchRawMaterials(merchantId);
});

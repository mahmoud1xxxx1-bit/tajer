import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/branch_inventory.dart';

class BranchInventoryRepository {
  final FirebaseFirestore firestore;
  final String merchantId;

  BranchInventoryRepository(this.firestore, this.merchantId);

  CollectionReference<Map<String, dynamic>> get ref =>
      firestore.collection('merchants').doc(merchantId).collection('branch_inventory');

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

  Future<double> changeQuantity({
    required String branchId,
    required String itemType,
    required String itemId,
    required double delta,
    required double legacyMainQuantity,
  }) async {
    final id = docId(branchId, itemType, itemId);
    final itemRef = ref.doc(id);
    return firestore.runTransaction<double>((tx) async {
      final snap = await tx.get(itemRef);
      final current = snap.exists
          ? (snap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
          : (branchId == 'main' ? legacyMainQuantity : 0.0);
      final next = current + delta;
      if (next < -0.000001) throw Exception('Insufficient branch inventory');
      tx.set(itemRef, {
        'id': id,
        'merchantId': merchantId,
        'branchId': branchId,
        'itemId': itemId,
        'itemType': itemType,
        'quantity': next < 0 ? 0.0 : next,
        'initialQuantity': snap.exists
            ? ((snap.data()?['initialQuantity'] as num?)?.toDouble() ?? current)
            : current,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next < 0 ? 0.0 : next;
    });
  }
}

final branchInventoryRepositoryProvider = Provider<BranchInventoryRepository?>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return null;
  return BranchInventoryRepository(FirebaseFirestore.instance, user.merchantId ?? user.id);
});

final branchInventoryStreamProvider = StreamProvider.family<List<BranchInventory>, String>((ref, branchId) {
  final repository = ref.watch(branchInventoryRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watch(branchId);
});

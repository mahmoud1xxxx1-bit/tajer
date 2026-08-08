import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/branch_inventory.dart';

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

  CollectionReference<Map<String, dynamic>> get ref =>
      firestore.collection('merchants').doc(merchantId).collection('branch_inventory');

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      firestore.collection('merchants').doc(merchantId).collection('inventory_logs');

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

  /// Sets an exact branch quantity and writes the corresponding audit record in
  /// the same Firestore transaction. This is the canonical path for manual
  /// stock counts/corrections from product and raw-material screens.
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
    if (quantity < -0.000001) {
      throw Exception('Branch inventory cannot be negative');
    }

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
          'initialQuantity': initial == 0.0 && current == 0.0
              ? normalizedQuantity
              : initial,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

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
          legacyMainQuantity: legacyMainQuantity,
        ),
      ],
    );
    return result[docId(branchId, itemType, itemId)]!;
  }

  /// Applies a complete sale/void inventory effect in one Firestore transaction.
  /// Every document is read before any write, so concurrent cashiers cannot
  /// oversell the same branch inventory and a failed item rolls back all items.
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
              legacyMainQuantity: mutation.legacyMainQuantity,
            );
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
        if (next < -0.000001) {
          throw Exception('Insufficient branch inventory: ${mutation.itemId}');
        }
        nextQuantities[entry.key] = next < 0 ? 0.0 : next;
      }

      for (final entry in merged.entries) {
        final mutation = entry.value;
        final snap = snapshots[entry.key]!;
        final current = snap.exists
            ? (snap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
            : (branchId == 'main' ? mutation.legacyMainQuantity : 0.0);
        tx.set(ref.doc(entry.key), {
          'id': entry.key,
          'merchantId': merchantId,
          'branchId': branchId,
          'itemId': mutation.itemId,
          'itemType': mutation.itemType,
          'quantity': nextQuantities[entry.key],
          'initialQuantity': snap.exists
              ? ((snap.data()?['initialQuantity'] as num?)?.toDouble() ?? current)
              : current,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return nextQuantities;
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

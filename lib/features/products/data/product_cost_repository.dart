import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_cost_repository.g.dart';

/// Sensitive product cost data is stored separately from product master data.
/// Firestore Rules can authorize this collection independently, unlike a field
/// inside a product document (Firestore rules cannot redact individual fields).
class ProductCostRepository {
  final FirebaseFirestore _firestore;

  ProductCostRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _ref(String merchantId) =>
      _firestore.collection('merchants').doc(merchantId).collection('product_costs');

  Stream<Map<String, double>> watchCosts(String merchantId) {
    return _ref(merchantId).snapshots().map((snapshot) {
      return <String, double>{
        for (final doc in snapshot.docs)
          if (doc.data()['costPrice'] is num)
            doc.id: (doc.data()['costPrice'] as num).toDouble(),
      };
    });
  }

  Future<void> setCost({
    required String merchantId,
    required String productId,
    required double? costPrice,
  }) async {
    final doc = _ref(merchantId).doc(productId);
    if (costPrice == null) {
      await doc.delete();
      return;
    }
    if (costPrice < 0) throw ArgumentError.value(costPrice, 'costPrice', 'Cost cannot be negative');
    await doc.set({
      'merchantId': merchantId,
      'productId': productId,
      'costPrice': costPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// One-way compatibility migration for v107 documents that stored costPrice
  /// directly inside /products. Run only for the merchant/admin. Each write
  /// first copies the cost to the protected collection, then deletes the legacy
  /// field in the same batch so employees without can_view_cost cannot retrieve
  /// it from normal product reads.
  Future<void> migrateLegacyCosts(String merchantId) async {
    final snapshot = await _firestore
        .collection('products')
        .where('merchantId', isEqualTo: merchantId)
        .get();

    final legacy = snapshot.docs.where((doc) => doc.data()['costPrice'] != null).toList();
    if (legacy.isEmpty) return;

    // Keep comfortably below Firestore's 500-write batch limit: each product
    // consumes two writes (protected cost + legacy field deletion).
    const productsPerBatch = 200;
    for (var start = 0; start < legacy.length; start += productsPerBatch) {
      final end = (start + productsPerBatch < legacy.length)
          ? start + productsPerBatch
          : legacy.length;
      final batch = _firestore.batch();
      for (final productDoc in legacy.sublist(start, end)) {
        final rawCost = productDoc.data()['costPrice'];
        if (rawCost is! num) continue;
        final costRef = _ref(merchantId).doc(productDoc.id);
        batch.set(costRef, {
          'merchantId': merchantId,
          'productId': productDoc.id,
          'costPrice': rawCost.toDouble(),
          'updatedAt': FieldValue.serverTimestamp(),
          'migratedFromLegacyProduct': true,
        }, SetOptions(merge: true));
        batch.update(productDoc.reference, {
          'costPrice': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}

@riverpod
ProductCostRepository productCostRepository(ProductCostRepositoryRef ref) {
  return ProductCostRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<Map<String, double>> productCostsStream(
  ProductCostsStreamRef ref,
  String merchantId,
) {
  return ref.watch(productCostRepositoryProvider).watchCosts(merchantId);
}

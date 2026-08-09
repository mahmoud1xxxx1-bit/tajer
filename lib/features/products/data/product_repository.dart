import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/product.dart';
import 'product_cost_repository.dart';

part 'product_repository.g.dart';

class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository(this._firestore);

  Query<Product> queryProducts(String merchantId) {
    return _firestore
        .collection('products')
        .where('merchantId', isEqualTo: merchantId)
        .where('isArchived', isEqualTo: false)
        .withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['price'] = (data['price'] ?? 0.0).toDouble();
        data['quantity'] = (data['quantity'] ?? 0).toInt();
        data['name'] = data['name']?.toString() ?? '';
        data['merchantId'] = data['merchantId']?.toString() ?? '';
        // Cost is intentionally not trusted from the public product record.
        // It is overlaid later from the protected product_costs collection.
        data.remove('costPrice');
        return Product.fromJson(data);
      },
      toFirestore: (product, _) {
        final data = product.toJson();
        data.remove('costPrice');
        return data;
      },
    );
  }

  Future<void> migrateOldProducts(String merchantId) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('merchantId', isEqualTo: merchantId)
          .get();
      final batch = _firestore.batch();
      int count = 0;
      for (var doc in snapshot.docs) {
        if (!doc.data().containsKey('isArchived')) {
          batch.update(doc.reference, {'isArchived': false});
          count++;
        }
      }
      if (count > 0) await batch.commit();
    } catch (e) {
      print('Migration error: $e');
    }
  }

  /// Product documents are merchant-wide master data. Quantities belong to
  /// branch_inventory. Sensitive cost data belongs to product_costs.
  Future<void> addProduct(Product product) async {
    final productRef = _firestore.collection('products').doc(product.id);
    final costRef = _firestore
        .collection('merchants')
        .doc(product.merchantId)
        .collection('product_costs')
        .doc(product.id);
    final data = product.toJson();
    data['quantity'] = 0;
    data.remove('costPrice');

    final batch = _firestore.batch();
    batch.set(productRef, data);
    if (product.costPrice != null) {
      batch.set(
          costRef,
          {
            'merchantId': product.merchantId,
            'productId': product.id,
            'costPrice': product.costPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Never overwrite the legacy merchant-wide quantity with the currently
  /// selected branch quantity. Cost is updated atomically in its protected doc.
  Future<void> updateProduct(Product product) async {
    final productRef = _firestore.collection('products').doc(product.id);
    final costRef = _firestore
        .collection('merchants')
        .doc(product.merchantId)
        .collection('product_costs')
        .doc(product.id);
    final data = product.toJson();
    data.remove('quantity');
    data.remove('costPrice');

    final batch = _firestore.batch();
    batch.update(productRef, data);
    if (product.costPrice == null) {
      batch.delete(costRef);
    } else {
      batch.set(
          costRef,
          {
            'merchantId': product.merchantId,
            'productId': product.id,
            'costPrice': product.costPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore
        .collection('products')
        .doc(productId)
        .update({'isArchived': true});
  }

  Future<int> getProductCount(String merchantId) async {
    final snapshot = await _firestore
        .collection('products')
        .where('merchantId', isEqualTo: merchantId)
        .get();
    return snapshot.docs
        .where((doc) => doc.data()['isArchived'] != true)
        .length;
  }
}

@riverpod
ProductRepository productRepository(ProductRepositoryRef ref) {
  return ProductRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<List<Product>> productsStream(ProductsStreamRef ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final repository = ref.watch(productRepositoryProvider);
  final costRepository = ref.watch(productCostRepositoryProvider);
  final merchantId = currentEffectiveMerchantId(appUser);
  final branchId = ref.watch(selectedBranchIdProvider);
  final branchInventory = ref.watch(branchInventoryStreamProvider(branchId));
  final canViewCost = appUser.hasPermission('can_view_cost');

  repository.migrateOldProducts(merchantId).catchError((_) {});

  // Only merchant/admin performs the destructive legacy cost migration. Until
  // it runs, queryProducts strips costPrice before deserialization. Protected
  // product_costs remains the source for authorized cost overlays.
  if (appUser.role == 'merchant' || appUser.role == 'admin') {
    costRepository.migrateLegacyCosts(merchantId).catchError((_) {});
  }

  final productSnapshots = repository.queryProducts(merchantId).snapshots();
  final costSnapshots = canViewCost
      ? costRepository.watchCosts(merchantId)
      : Stream<Map<String, double>>.value(const <String, double>{});

  return productSnapshots.asyncExpand((snapshot) {
    final baseProducts = snapshot.docs.map((doc) => doc.data()).toList();
    return costSnapshots.map((costs) {
      final inventory = branchInventory.valueOrNull ?? const [];
      final quantities = <String, double>{
        for (final item in inventory)
          if (item.itemType == 'product') item.itemId: item.quantity,
      };

      var products = baseProducts.map((product) {
        final scopedQuantity = quantities[product.id];
        var next = product;
        if (scopedQuantity != null) {
          next = next.copyWith(quantity: scopedQuantity.round());
        } else if (branchId != 'main') {
          // Backward compatibility: only Main Branch inherits v107 stock.
          next = next.copyWith(quantity: 0);
        }
        if (canViewCost) {
          final cost = costs[product.id];
          if (cost != null) next = next.copyWith(costPrice: cost);
        }
        return next;
      }).toList();

      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products;
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/product.dart';
import 'product_cost_repository.dart';

part 'product_repository.g.dart';

class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _branchProductsRef(
    String merchantId,
    String branchId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .collection('products');

  DocumentReference<Map<String, dynamic>> _branchProductRef(
    String merchantId,
    String branchId,
    String productId,
  ) =>
      _branchProductsRef(merchantId, branchId).doc(productId);

  DocumentReference<Map<String, dynamic>> _productCostRef(
    String merchantId,
    String branchId,
    String productId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('product_costs')
          .doc('${branchId}_$productId');

  Query<Product> queryProducts(String merchantId, String branchId) {
    return _branchProductsRef(merchantId, branchId)
        .where('isArchived', isEqualTo: false)
        .withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['price'] = (data['price'] ?? 0.0).toDouble();
        data['quantity'] = (data['quantity'] ?? 0).toInt();
        data['name'] = data['name']?.toString() ?? '';
        data['merchantId'] = data['merchantId']?.toString() ?? merchantId;
        data['branchId'] = data['branchId']?.toString() ?? branchId;
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

  Query<Product> queryLegacyProducts(String merchantId) {
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

  CollectionReference<Map<String, dynamic>> _availabilityRef(
    String merchantId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('product_branch_availability');

  String availabilityDocId(String branchId, String productId) =>
      '${branchId}_$productId';

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

  DocumentReference<Map<String, dynamic>> _productMigrationStateRef(
    String merchantId,
    String branchId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('branch_catalog_v1_$branchId');

  Future<bool> isBranchCatalogMigrationCompleted({
    required String merchantId,
    required String branchId,
  }) async {
    final state = await _productMigrationStateRef(merchantId, branchId).get();
    return state.data()?['status'] == 'completed';
  }

  Future<void> migrateBranchCatalogPage({
    required String merchantId,
    required String branchId,
    int pageSize = 400,
  }) async {
    final stateRef = _productMigrationStateRef(merchantId, branchId);
    final state = await stateRef.get();
    if (state.data()?['status'] == 'completed') return;
    final lastLegacyProductId =
        state.data()?['lastLegacyProductId']?.toString();

    var query = _firestore
        .collection('products')
        .where('merchantId', isEqualTo: merchantId);
    if (lastLegacyProductId != null && lastLegacyProductId.isNotEmpty) {
      query = query.where('id', isGreaterThan: lastLegacyProductId);
    }
    query = query.orderBy('id').limit(pageSize);
    final legacyProducts = await query.get();
    final availability = await _availabilityRef(merchantId).get();
    final inventory = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .where('branchId', isEqualTo: branchId)
        .where('itemType', isEqualTo: 'product')
        .get();

    final explicit = <String, bool>{};
    final anyExplicit = <String>{};
    for (final doc in availability.docs) {
      final data = doc.data();
      final productId = data['productId']?.toString();
      final availabilityBranchId = data['branchId']?.toString();
      if (productId == null || productId.isEmpty) continue;
      anyExplicit.add(productId);
      if (availabilityBranchId == branchId) {
        explicit[productId] = data['enabled'] == true;
      }
    }
    final inventoryEvidence = {
      for (final doc in inventory.docs) doc.data()['itemId']?.toString() ?? '',
    }..remove('');

    if (legacyProducts.docs.isEmpty) {
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

    var lastProcessedId = lastLegacyProductId;
    for (final doc in legacyProducts.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final productId = doc.id;
      lastProcessedId = productId;
      final enabled = explicit[productId];
      final belongsToBranch = enabled ??
          (anyExplicit.contains(productId)
              ? false
              : (inventoryEvidence.contains(productId) || branchId == 'main'));
      if (!belongsToBranch) continue;
      data['id'] = productId;
      data['merchantId'] = merchantId;
      data['branchId'] = branchId;
      data['quantity'] = 0;
      data.remove('costPrice');
      batch.set(
        _branchProductRef(merchantId, branchId, productId),
        data,
        SetOptions(merge: true),
      );
    }

    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': branchId,
          'lastLegacyProductId': lastProcessedId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> migrateBranchCatalogIfNeeded({
    required String merchantId,
    required String branchId,
    int pageSize = 400,
  }) async {
    for (var i = 0; i < 1000; i++) {
      await migrateBranchCatalogPage(
        merchantId: merchantId,
        branchId: branchId,
        pageSize: pageSize,
      );
      if (await isBranchCatalogMigrationCompleted(
        merchantId: merchantId,
        branchId: branchId,
      )) {
        return;
      }
    }
    await _productMigrationStateRef(merchantId, branchId).set({
      'version': 1,
      'status': 'failed',
      'branchId': branchId,
      'lastError': 'Product migration exceeded maximum page count',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    throw StateError('Product migration exceeded maximum page count');
  }

  Future<List<Product>> readLegacyProductsForBranch({
    required String merchantId,
    required String branchId,
  }) async {
    final legacyProducts = await _firestore
        .collection('products')
        .where('merchantId', isEqualTo: merchantId)
        .where('isArchived', isEqualTo: false)
        .get();
    final availability = await _availabilityRef(merchantId).get();
    final inventory = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .where('branchId', isEqualTo: branchId)
        .where('itemType', isEqualTo: 'product')
        .get();
    final explicit = <String, bool>{};
    final anyExplicit = <String>{};
    for (final doc in availability.docs) {
      final data = doc.data();
      final productId = data['productId']?.toString();
      final availabilityBranchId = data['branchId']?.toString();
      if (productId == null || productId.isEmpty) continue;
      anyExplicit.add(productId);
      if (availabilityBranchId == branchId) {
        explicit[productId] = data['enabled'] == true;
      }
    }
    final inventoryEvidence = {
      for (final doc in inventory.docs) doc.data()['itemId']?.toString() ?? '',
    }..remove('');

    return legacyProducts.docs.where((doc) {
      final productId = doc.id;
      final enabled = explicit[productId];
      return enabled ??
          (anyExplicit.contains(productId)
              ? false
              : (inventoryEvidence.contains(productId) || branchId == 'main'));
    }).map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['merchantId'] = data['merchantId']?.toString() ?? merchantId;
      data['branchId'] = branchId;
      data['price'] = (data['price'] ?? 0.0).toDouble();
      data['quantity'] = 0;
      data.remove('costPrice');
      return Product.fromJson(data);
    }).toList();
  }

  /// Product documents are branch-owned operational catalog data. Quantities
  /// belong to branch_inventory. Sensitive cost data belongs to product_costs.
  Future<void> addProduct(
    Product product, {
    required BranchOperationContext context,
    required Set<String> enabledBranchIds,
    Set<String> knownBranchIds = const <String>{},
  }) async {
    if (product.merchantId != context.merchantId) {
      throw StateError('Product merchant mismatch');
    }
    final productRef =
        _branchProductRef(context.merchantId, context.branchId, product.id);
    final costRef =
        _productCostRef(context.merchantId, context.branchId, product.id);
    final data = product.toJson();
    data['quantity'] = 0;
    data.remove('costPrice');

    data['branchId'] = context.branchId;

    final batch = _firestore.batch();
    batch.set(productRef, data);
    if (product.costPrice != null) {
      batch.set(
          costRef,
          {
            'merchantId': product.merchantId,
            'branchId': context.branchId,
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
  Future<void> updateProduct(
    Product product, {
    required BranchOperationContext context,
  }) async {
    final productRef =
        _branchProductRef(context.merchantId, context.branchId, product.id);
    final costRef =
        _productCostRef(context.merchantId, context.branchId, product.id);
    final data = product.toJson();
    data.remove('quantity');
    data.remove('costPrice');
    data['branchId'] = context.branchId;

    final batch = _firestore.batch();
    batch.update(productRef, data);
    if (product.costPrice == null) {
      batch.delete(costRef);
    } else {
      batch.set(
          costRef,
          {
            'merchantId': product.merchantId,
            'branchId': context.branchId,
            'productId': product.id,
            'costPrice': product.costPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> removeProductFromBranch({
    required BranchOperationContext context,
    required String productId,
  }) async {
    if (!context.isValid) throw StateError('Invalid branch operation context');
    await _branchProductRef(context.merchantId, context.branchId, productId)
        .update({
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveProductFromStore({
    required BranchOperationContext context,
    required String productId,
  }) async {
    await _branchProductRef(context.merchantId, context.branchId, productId)
        .update({
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
  if (branchId.isEmpty) return const Stream.empty();
  final branchInventory = ref.watch(branchInventoryStreamProvider(branchId));
  final canViewCost = appUser.hasPermission('can_view_cost');

  // Only merchant/admin performs the destructive legacy cost migration. Until
  // it runs, queryProducts strips costPrice before deserialization. Protected
  // product_costs remains the source for authorized cost overlays.
  if (appUser.role == 'merchant' || appUser.role == 'admin') {
    costRepository.migrateLegacyCosts(merchantId).catchError((_) {});
  }

  final productSnapshots =
      repository.queryProducts(merchantId, branchId).snapshots();
  final costSnapshots = canViewCost
      ? costRepository.watchCosts(merchantId)
      : Stream<Map<String, double>>.value(const <String, double>{});

  return productSnapshots.asyncExpand((snapshot) {
    return costSnapshots.asyncMap((costs) async {
      var baseProducts = snapshot.docs.map((doc) => doc.data()).toList();
      final migrationCompleted =
          await repository.isBranchCatalogMigrationCompleted(
        merchantId: merchantId,
        branchId: branchId,
      );
      if (!migrationCompleted) {
        baseProducts = await repository.readLegacyProductsForBranch(
          merchantId: merchantId,
          branchId: branchId,
        );
      }
      final inventory = branchInventory.valueOrNull ?? const [];
      final quantities = <String, double>{
        for (final item in inventory)
          if (item.itemType == 'product') item.itemId: item.quantity,
      };

      final products = baseProducts.map((product) {
        final scopedQuantity = quantities[product.id];
        var next = product.copyWith(quantity: (scopedQuantity ?? 0).round());
        if (canViewCost) {
          final cost = costs['${branchId}_${product.id}'] ?? costs[product.id];
          if (cost != null) next = next.copyWith(costPrice: cost);
        }
        return next;
      }).toList();

      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products;
    });
  });
}

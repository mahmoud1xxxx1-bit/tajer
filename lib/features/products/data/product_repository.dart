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

  CollectionReference<Map<String, dynamic>> _availabilityRef(
    String merchantId,
  ) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('product_branch_availability');

  String availabilityDocId(String branchId, String productId) =>
      '${branchId}_$productId';

  Stream<Map<String, bool>> watchAvailability(
      String merchantId, String branchId) {
    return _availabilityRef(merchantId)
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map((snapshot) {
      return {
        for (final doc in snapshot.docs)
          '${doc.data()['productId']}::${doc.data()['branchId']}':
              doc.data()['enabled'] == true,
      };
    });
  }

  Stream<Map<String, bool>> watchProductAvailability({
    required String merchantId,
    required String productId,
  }) {
    return _availabilityRef(merchantId)
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
      return {
        for (final doc in snapshot.docs)
          doc.data()['branchId']?.toString() ?? '':
              doc.data()['enabled'] == true,
      };
    });
  }

  Future<void> setProductAvailability({
    required BranchOperationContext context,
    required String productId,
    required Set<String> enabledBranchIds,
    Set<String> knownBranchIds = const <String>{},
  }) async {
    if (!context.isValid) throw StateError('Invalid branch operation context');
    final existing = await _availabilityRef(context.merchantId)
        .where('productId', isEqualTo: productId)
        .get();
    final allBranchIds = <String>{
      ...knownBranchIds,
      ...enabledBranchIds,
      for (final doc in existing.docs) doc.data()['branchId']?.toString() ?? '',
    }..removeWhere((branchId) => branchId.isEmpty);

    final batch = _firestore.batch();
    for (final branchId in allBranchIds) {
      final ref = _availabilityRef(context.merchantId)
          .doc(availabilityDocId(branchId, productId));
      batch.set(
        ref,
        {
          'id': ref.id,
          'merchantId': context.merchantId,
          'branchId': branchId,
          'productId': productId,
          'enabled': enabledBranchIds.contains(branchId),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
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
  Future<void> addProduct(
    Product product, {
    required BranchOperationContext context,
    required Set<String> enabledBranchIds,
    Set<String> knownBranchIds = const <String>{},
  }) async {
    if (product.merchantId != context.merchantId) {
      throw StateError('Product merchant mismatch');
    }
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
    final branchesToWrite = <String>{...knownBranchIds, ...enabledBranchIds}
      ..removeWhere((branchId) => branchId.isEmpty);
    for (final branchId in branchesToWrite) {
      final availabilityRef = _availabilityRef(product.merchantId)
          .doc(availabilityDocId(branchId, product.id));
      batch.set(availabilityRef, {
        'id': availabilityRef.id,
        'merchantId': product.merchantId,
        'branchId': branchId,
        'productId': product.id,
        'enabled': enabledBranchIds.contains(branchId),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
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

  Future<void> removeProductFromBranch({
    required BranchOperationContext context,
    required String productId,
  }) async {
    if (!context.isValid) throw StateError('Invalid branch operation context');
    final ref = _availabilityRef(context.merchantId)
        .doc(availabilityDocId(context.branchId, productId));
    await ref.set({
      'id': ref.id,
      'merchantId': context.merchantId,
      'branchId': context.branchId,
      'productId': productId,
      'enabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> archiveProductFromStore(String productId) async {
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
  if (branchId.isEmpty) return const Stream.empty();
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
  final availabilitySnapshots =
      repository.watchAvailability(merchantId, branchId);
  final costSnapshots = canViewCost
      ? costRepository.watchCosts(merchantId)
      : Stream<Map<String, double>>.value(const <String, double>{});

  return productSnapshots.asyncExpand((snapshot) {
    final baseProducts = snapshot.docs.map((doc) => doc.data()).toList();
    return availabilitySnapshots.asyncExpand((availability) {
      return costSnapshots.map((costs) {
        final inventory = branchInventory.valueOrNull ?? const [];
        final quantities = <String, double>{
          for (final item in inventory)
            if (item.itemType == 'product') item.itemId: item.quantity,
        };
        final inventoryEvidence = quantities.keys.toSet();

        var products = baseProducts.where((product) {
          final key = '${product.id}::$branchId';
          final explicit = availability[key];
          if (explicit != null) return explicit;
          // Legacy compatibility: products without explicit availability remain
          // visible in Main, or in branches that already have inventory rows.
          return branchId == 'main' || inventoryEvidence.contains(product.id);
        }).map((product) {
          final scopedQuantity = quantities[product.id];
          var next = product;
          if (scopedQuantity != null) {
            next = next.copyWith(quantity: scopedQuantity.round());
          } else if (branchId != 'main') {
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
  });
}

class ProductAvailabilityQuery {
  final String merchantId;
  final String productId;

  const ProductAvailabilityQuery({
    required this.merchantId,
    required this.productId,
  });

  @override
  bool operator ==(Object other) =>
      other is ProductAvailabilityQuery &&
      other.merchantId == merchantId &&
      other.productId == productId;

  @override
  int get hashCode => Object.hash(merchantId, productId);
}

final productAvailabilityStreamProvider =
    StreamProvider.family<Map<String, bool>, ProductAvailabilityQuery>(
  (ref, query) {
    return ref.watch(productRepositoryProvider).watchProductAvailability(
          merchantId: query.merchantId,
          productId: query.productId,
        );
  },
);

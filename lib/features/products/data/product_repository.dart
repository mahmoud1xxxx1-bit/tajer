import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/product.dart';

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
            return Product.fromJson(data);
          },
          toFirestore: (product, _) => product.toJson(),
        );
  }

  Future<void> migrateOldProducts(String merchantId) async {
    try {
      final snapshot = await _firestore.collection('products').where('merchantId', isEqualTo: merchantId).get();
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

  Future<void> addProduct(Product product) async {
    await _firestore.collection('products').doc(product.id).set(product.toJson());
  }

  Future<void> updateProduct(Product product) async {
    await _firestore.collection('products').doc(product.id).update(product.toJson());
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).update({'isArchived': true});
  }

  Future<int> getProductCount(String merchantId) async {
    final snapshot = await _firestore.collection('products').where('merchantId', isEqualTo: merchantId).get();
    return snapshot.docs.where((doc) => doc.data()['isArchived'] != true).length;
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
  final merchantId = appUser.merchantId ?? appUser.id;
  final branchId = ref.watch(selectedBranchIdProvider);
  final branchInventory = ref.watch(branchInventoryStreamProvider(branchId));

  repository.migrateOldProducts(merchantId).catchError((_) {});

  return repository.queryProducts(merchantId).snapshots().map((snapshot) {
    var products = snapshot.docs.map((doc) => doc.data()).toList();
    final inventory = branchInventory.valueOrNull ?? const [];
    final quantities = <String, double>{
      for (final item in inventory)
        if (item.itemType == 'product') item.itemId: item.quantity,
    };

    products = products.map((product) {
      final scopedQuantity = quantities[product.id];
      if (scopedQuantity != null) {
        return product.copyWith(quantity: scopedQuantity.round());
      }
      // Backward compatibility: only Main Branch inherits the legacy v107 stock.
      if (branchId == 'main') return product;
      return product.copyWith(quantity: 0);
    }).toList();

    products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return products;
  });
}

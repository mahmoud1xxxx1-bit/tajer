import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
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
            // Also ensure numeric/string types don't crash if malformed
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
      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('Migration error: $e');
    }
  }

  Future<void> addProduct(Product product) async {
    final docRef = _firestore.collection('products').doc(product.id);
    await docRef.set(product.toJson());
  }

  Future<void> updateProduct(Product product) async {
    final docRef = _firestore.collection('products').doc(product.id);
    await docRef.update(product.toJson());
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'isArchived': true,
    });
  }

  Future<int> getProductCount(String merchantId) async {
    final snapshot = await _firestore
        .collection('products')
        .where('merchantId', isEqualTo: merchantId)
        .get();
        
    int activeCount = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final isArchived = data['isArchived'] == true;
      if (!isArchived) activeCount++;
    }
    return activeCount;
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
  
  // Run background migration for missing fields
  repository.migrateOldProducts(appUser.merchantId ?? appUser.id).catchError((_) {});

  return repository.queryProducts(appUser.merchantId ?? appUser.id).snapshots().map(
        (snapshot) {
          var products = snapshot.docs.map((doc) => doc.data()).toList();
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return products;
        },
      );
}

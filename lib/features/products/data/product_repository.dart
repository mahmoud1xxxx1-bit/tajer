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
        .withConverter(
          fromFirestore: (snapshot, _) {
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            // Also ensure numeric/string types don't crash if malformed
            data['price'] = (data['price'] ?? 0.0).toDouble();
            data['quantity'] = (data['quantity'] ?? 0).toInt();
            data['name'] = data['name']?.toString() ?? '';
            return Product.fromJson(data);
          },
          toFirestore: (product, _) => product.toJson(),
        );
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
    await _firestore.collection('products').doc(productId).delete();
  }

  Future<int> getProductCount(String merchantId) async {
    final snapshot = await _firestore
        .collection('products')
        .where('merchantId', isEqualTo: merchantId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

@riverpod
ProductRepository productRepository(ProductRepositoryRef ref) {
  return ProductRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<List<Product>> productsStream(ProductsStreamRef ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return const Stream.empty();

  final repository = ref.watch(productRepositoryProvider);
  return repository.queryProducts(user.uid).snapshots().map(
        (snapshot) {
          final products = snapshot.docs.map((doc) => doc.data()).toList();
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return products;
        },
      );
}

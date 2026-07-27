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
        .orderBy('createdAt', descending: true)
        .withConverter(
          fromFirestore: (snapshot, _) => Product.fromJson(snapshot.data()!),
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
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
      );
}

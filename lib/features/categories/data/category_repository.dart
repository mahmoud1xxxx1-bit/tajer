import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/category.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  CategoryRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('categories');

  Stream<List<Category>> watchCategories() {
    return _categoriesRef.withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['merchantId'] = data['merchantId']?.toString() ?? '';
        data['name'] = data['name']?.toString() ?? '';
        if (data['createdAt'] == null) {
          data['createdAt'] = Timestamp.now();
        }
        return Category.fromJson(data);
      },
      toFirestore: (category, _) => category.toJson(),
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addCategory(Category category) async {
    await _categoriesRef.doc(category.id).set(category.toJson());
  }

  Future<void> updateCategory(Category category) async {
    await _categoriesRef.doc(category.id).update(category.toJson());
  }

  Future<void> deleteCategory(String categoryId) async {
    await _categoriesRef.doc(categoryId).delete();
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return CategoryRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchCategories();
});


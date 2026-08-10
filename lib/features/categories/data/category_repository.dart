import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/category.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;
  final String _branchId;

  CategoryRepository(this._firestore, this._merchantId, this._branchId);

  CollectionReference<Map<String, dynamic>> get _categoriesRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('branches')
      .doc(_branchId)
      .collection('categories');

  Stream<List<Category>> watchCategories() {
    migrateBranchCategoriesIfNeeded().catchError((_) {});
    return _categoriesRef
        .withConverter(
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
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> migrateBranchCategoriesIfNeeded() async {
    final stateRef = _firestore
        .collection('merchants')
        .doc(_merchantId)
        .collection('migration_state')
        .doc('branch_categories_v1_$_branchId');
    final state = await stateRef.get();
    if (state.data()?['status'] == 'completed') return;

    final legacy = await _firestore
        .collection('merchants')
        .doc(_merchantId)
        .collection('categories')
        .get();
    final batch = _firestore.batch();
    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': _branchId,
          'startedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    for (final doc in legacy.docs.take(450)) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['merchantId'] = _merchantId;
      data['branchId'] = _branchId;
      batch.set(_categoriesRef.doc(doc.id), data, SetOptions(merge: true));
    }
    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'completed',
          'branchId': _branchId,
          'completedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> addCategory(
    Category category, {
    required BranchOperationContext context,
  }) async {
    if (context.merchantId != _merchantId || context.branchId != _branchId) {
      throw StateError('Category branch context mismatch');
    }
    await _categoriesRef.doc(category.id).set(category.toJson());
  }

  Future<void> updateCategory(
    Category category, {
    required BranchOperationContext context,
  }) async {
    if (context.merchantId != _merchantId || context.branchId != _branchId) {
      throw StateError('Category branch context mismatch');
    }
    await _categoriesRef.doc(category.id).update(category.toJson());
  }

  Future<void> deleteCategory(
    String categoryId, {
    required BranchOperationContext context,
  }) async {
    if (context.merchantId != _merchantId || context.branchId != _branchId) {
      throw StateError('Category branch context mismatch');
    }
    final productsSnap = await _firestore
        .collection('merchants')
        .doc(_merchantId)
        .collection('branches')
        .doc(_branchId)
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .get();

    final batch = _firestore.batch();
    for (var doc in productsSnap.docs) {
      batch.update(doc.reference, {'categoryId': ''});
    }
    batch.delete(_categoriesRef.doc(categoryId));
    await batch.commit();
  }

  Future<void> seedDefaultCategories() async {
    final defaults = [
      'إلكترونيات',
      'ملابس',
      'بقالة',
      'عطور ومستحضرات تجميل',
      'أدوات منزلية',
      'أخرى'
    ];
    for (final name in defaults) {
      final docRef = _categoriesRef.doc();
      final category = Category(
        id: docRef.id,
        merchantId: _merchantId,
        name: name,
        createdAt: DateTime.now(),
      );
      await docRef.set(category.toJson());
    }
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return null;
  return CategoryRepository(
    FirebaseFirestore.instance,
    currentEffectiveMerchantId(appUser),
    branchId,
  );
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchCategories();
});

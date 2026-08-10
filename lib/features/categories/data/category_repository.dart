import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../../core/services/legacy_catalog_migration_normalizer.dart';
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

  DocumentReference<Map<String, dynamic>> get _migrationStateRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('migration_state')
      .doc('branch_categories_v1_$_branchId');

  Future<bool> isBranchCategoryMigrationCompleted() async {
    final state = await _migrationStateRef.get();
    return state.data()?['status'] == 'completed';
  }

  Future<void> migrateBranchCategoriesPage({int pageSize = 400}) async {
    final stateRef = _migrationStateRef;
    final state = await stateRef.get();
    if (state.data()?['status'] == 'completed') return;
    final lastLegacyCategoryId =
        state.data()?['lastLegacyCategoryId']?.toString();

    Query<Map<String, dynamic>> query = _firestore
        .collection('merchants')
        .doc(_merchantId)
        .collection('categories');
    if (lastLegacyCategoryId != null && lastLegacyCategoryId.isNotEmpty) {
      query = query.where(FieldPath.documentId,
          isGreaterThan: lastLegacyCategoryId);
    }
    query = query.orderBy(FieldPath.documentId).limit(pageSize);
    final legacy = await query.get();
    if (legacy.docs.isEmpty) {
      await stateRef.set({
        'version': 1,
        'status': 'completed',
        'branchId': _branchId,
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
          'branchId': _branchId,
          'lastError': FieldValue.delete(),
          'startedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    var lastProcessedId = lastLegacyCategoryId;
    for (final doc in legacy.docs) {
      lastProcessedId = doc.id;
      final data = normalizeLegacyCategoryForBranch(
        document: doc,
        merchantId: _merchantId,
        branchId: _branchId,
      );
      batch.set(_categoriesRef.doc(doc.id), data, SetOptions(merge: true));
    }
    batch.set(
        stateRef,
        {
          'version': 1,
          'status': 'running',
          'branchId': _branchId,
          'lastLegacyCategoryId': lastProcessedId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> migrateBranchCategoriesIfNeeded({int pageSize = 400}) async {
    for (var i = 0; i < 1000; i++) {
      await migrateBranchCategoriesPage(pageSize: pageSize);
      if (await isBranchCategoryMigrationCompleted()) return;
    }
    await _migrationStateRef.set({
      'version': 1,
      'status': 'failed',
      'branchId': _branchId,
      'lastError': 'Category migration exceeded maximum page count',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    throw StateError('Category migration exceeded maximum page count');
  }

  Future<List<Category>> readLegacyCategories() async {
    // Preserve empty legacy categories until the owner completes migration so
    // branches do not appear to have lost intentionally-created catalog groups.
    final legacy = await _firestore
        .collection('merchants')
        .doc(_merchantId)
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .get();
    return legacy.docs.map((doc) {
      final data = normalizeLegacyCategoryForBranch(
        document: doc,
        merchantId: _merchantId,
        branchId: _branchId,
      );
      return Category.fromJson(data);
    }).toList();
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
  return repo.watchCategories().asyncExpand((categories) async* {
    if (await repo.isBranchCategoryMigrationCompleted()) {
      yield categories;
    } else {
      yield await repo.readLegacyCategories();
    }
  });
});

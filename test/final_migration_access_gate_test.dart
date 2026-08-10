import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/services/branch_catalog_migration_bootstrap_service.dart';
import 'package:tajer/features/products/data/product_repository.dart';
import 'package:tajer/features/products/data/raw_material_repository.dart';

const merchantId = 'merchant_final_gate';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('final migration access gate', () {
    test('branch-local legacy adapters do not query merchant-wide availability',
        () {
      final productSource =
          File('lib/features/products/data/product_repository.dart')
              .readAsStringSync();
      final rawSource =
          File('lib/features/products/data/raw_material_repository.dart')
              .readAsStringSync();
      final productAdapter = productSource
          .split('Future<List<Product>> readLegacyProductsForBranch')
          .last;
      final rawAdapter = rawSource
          .split('Future<List<RawMaterial>> readLegacyRawMaterialsForBranch')
          .last;

      expect(productAdapter,
          isNot(contains('_availabilityRef(merchantId).get()')));
      expect(rawAdapter, isNot(contains('_availabilityRef(merchantId).get()')));
      expect(productAdapter, contains('_legacyVisibilityRef'));
      expect(rawAdapter, contains('_legacyVisibilityRef'));
    });

    test('employee pending compatibility reads only branch-local manifests',
        () async {
      final db = FakeFirebaseFirestore();
      await _seedBranches(db);
      await _seedProduct(db, 'prod_a');
      await _seedProduct(db, 'prod_b');
      await _seedProduct(db, 'prod_global');
      await _seedRaw(db, 'raw_a');
      await _seedRaw(db, 'raw_b');
      await _seedAvailability(db,
          collection: 'product_branch_availability',
          id: 'branch-a_prod_a',
          branchId: 'branch-a',
          itemField: 'productId',
          itemId: 'prod_a');
      await _seedAvailability(db,
          collection: 'product_branch_availability',
          id: 'branch-b_prod_b',
          branchId: 'branch-b',
          itemField: 'productId',
          itemId: 'prod_b');
      await _seedAvailability(db,
          collection: 'raw_material_branch_availability',
          id: 'branch-a_raw_a',
          branchId: 'branch-a',
          itemField: 'rawMaterialId',
          itemId: 'raw_a');
      await _seedAvailability(db,
          collection: 'raw_material_branch_availability',
          id: 'branch-b_raw_b',
          branchId: 'branch-b',
          itemField: 'rawMaterialId',
          itemId: 'raw_b');

      final productRepo = ProductRepository(db);
      final rawRepo = RawMaterialRepository(db);
      await productRepo.buildLegacyProductVisibilityManifestIfNeeded(
        merchantId: merchantId,
        branchId: 'branch-a',
      );
      await rawRepo.buildLegacyRawMaterialVisibilityManifestIfNeeded(
        merchantId: merchantId,
        branchId: 'branch-a',
      );
      await productRepo.buildLegacyProductVisibilityManifestIfNeeded(
        merchantId: merchantId,
        branchId: 'main',
      );
      await rawRepo.buildLegacyRawMaterialVisibilityManifestIfNeeded(
        merchantId: merchantId,
        branchId: 'main',
      );

      final branchAProducts = await productRepo.readLegacyProductsForBranch(
        merchantId: merchantId,
        branchId: 'branch-a',
      );
      final branchARaw = await rawRepo.readLegacyRawMaterialsForBranch(
        merchantId: merchantId,
        branchId: 'branch-a',
      );
      final mainProducts = await productRepo.readLegacyProductsForBranch(
        merchantId: merchantId,
        branchId: 'main',
      );
      final mainRaw = await rawRepo.readLegacyRawMaterialsForBranch(
        merchantId: merchantId,
        branchId: 'main',
      );

      expect(branchAProducts.map((item) => item.id), contains('prod_a'));
      expect(branchAProducts.map((item) => item.id), isNot(contains('prod_b')));
      expect(branchARaw.map((item) => item.id), contains('raw_a'));
      expect(branchARaw.map((item) => item.id), isNot(contains('raw_b')));
      expect(mainProducts.map((item) => item.id), isNot(contains('prod_b')));
      expect(mainRaw.map((item) => item.id), isNot(contains('raw_b')));
      expect(mainProducts.map((item) => item.id), contains('prod_global'));
    });

    test('owner bootstrap completes product raw and category migrations once',
        () async {
      final db = FakeFirebaseFirestore();
      await _seedBranches(db);
      await _seedProduct(db, 'prod_a');
      await _seedProduct(db, 'prod_b');
      await _seedRaw(db, 'raw_a');
      await _seedRaw(db, 'raw_b');
      await _seedCategory(db, 'cat_1');
      await _seedAvailability(db,
          collection: 'product_branch_availability',
          id: 'branch-a_prod_a',
          branchId: 'branch-a',
          itemField: 'productId',
          itemId: 'prod_a');
      await _seedAvailability(db,
          collection: 'raw_material_branch_availability',
          id: 'branch-a_raw_a',
          branchId: 'branch-a',
          itemField: 'rawMaterialId',
          itemId: 'raw_a');

      final service = BranchCatalogMigrationBootstrapService(db);
      await service.runForOwner(merchantId: merchantId);
      await service.runForOwner(merchantId: merchantId);

      expect(await _count(db, 'branches/branch-a/products'), 1);
      expect(await _count(db, 'branches/branch-a/raw_materials'), 1);
      expect(await _count(db, 'branches/branch-a/categories'), 1);
      expect(await _state(db, 'branch_catalog_v1_branch-a'), 'completed');
      expect(await _state(db, 'branch_raw_materials_v1_branch-a'), 'completed');
      expect(await _state(db, 'branch_categories_v1_branch-a'), 'completed');
      expect(await _state(db, 'legacy_product_visibility_v1_branch-a'),
          'completed');
      expect(await _state(db, 'legacy_raw_material_visibility_v1_branch-a'),
          'completed');
    });

    test('employee startup contracts do not invoke migration writes', () {
      final productSource =
          File('lib/features/products/data/product_repository.dart')
              .readAsStringSync();
      final rawSource =
          File('lib/features/products/data/raw_material_repository.dart')
              .readAsStringSync();
      final categorySource =
          File('lib/features/categories/data/category_repository.dart')
              .readAsStringSync();
      final dashboardSource =
          File('lib/features/dashboard/presentation/dashboard_screen.dart')
              .readAsStringSync();

      expect(productSource, isNot(contains('.migrateBranchCatalogIfNeeded(')));
      expect(rawSource, isNot(contains('.migrateBranchRawMaterialsIfNeeded(')));
      expect(
          categorySource, isNot(contains('.migrateBranchCategoriesIfNeeded(')));
      expect(dashboardSource, contains("appUser.role == 'merchant'"));
      expect(
          dashboardSource, contains('branchCatalogMigrationBootstrapProvider'));
    });
  });
}

Future<void> _seedBranches(FakeFirebaseFirestore db) async {
  for (final branchId in ['main', 'branch-a', 'branch-b']) {
    await db
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(branchId)
        .set({
      'id': branchId,
      'merchantId': merchantId,
      'name': branchId,
      'isMain': branchId == 'main',
      'isActive': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }
}

Future<void> _seedProduct(FakeFirebaseFirestore db, String id) {
  return db.collection('products').doc(id).set({
    'id': id,
    'merchantId': merchantId,
    'name': id,
    'price': 10.0,
    'quantity': 0,
    'modifiers': <String>[],
    'recipe': <Map<String, Object?>>[],
    'isArchived': false,
    'taxMode': 'store',
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> _seedRaw(FakeFirebaseFirestore db, String id) {
  return db.collection('raw_materials').doc(id).set({
    'id': id,
    'merchantId': merchantId,
    'name': id,
    'quantity': 0.0,
    'initialQuantity': 0.0,
    'unit': 'piece',
    'isArchived': false,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> _seedCategory(FakeFirebaseFirestore db, String id) {
  return db
      .collection('merchants')
      .doc(merchantId)
      .collection('categories')
      .doc(id)
      .set({
    'id': id,
    'merchantId': merchantId,
    'name': id,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> _seedAvailability(
  FakeFirebaseFirestore db, {
  required String collection,
  required String id,
  required String branchId,
  required String itemField,
  required String itemId,
}) {
  return db
      .collection('merchants')
      .doc(merchantId)
      .collection(collection)
      .doc(id)
      .set({
    'id': id,
    'merchantId': merchantId,
    'branchId': branchId,
    itemField: itemId,
    'enabled': true,
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<int> _count(FakeFirebaseFirestore db, String branchPath) async {
  final parts = branchPath.split('/');
  final snap = await db
      .collection('merchants')
      .doc(merchantId)
      .collection(parts[0])
      .doc(parts[1])
      .collection(parts[2])
      .get();
  return snap.docs.length;
}

Future<String?> _state(FakeFirebaseFirestore db, String id) async {
  final snap = await db
      .collection('merchants')
      .doc(merchantId)
      .collection('migration_state')
      .doc(id)
      .get();
  return snap.data()?['status']?.toString();
}

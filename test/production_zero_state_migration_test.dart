import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/services/branch_catalog_migration_bootstrap_service.dart';
import 'package:tajer/core/services/legacy_catalog_migration_normalizer.dart';
import 'package:tajer/features/products/data/product_repository.dart';

const _merchantId = 'zero-state-merchant';
const _branches = ['main', 'branch-a', 'branch-b'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production-shaped zero-state bootstrap completes and is idempotent',
      () async {
    final db = FakeFirebaseFirestore();
    await _seedBranches(db);
    await _seedProduct(db, 'product-main');
    await _seedProduct(db, 'product-a');
    await _seedProduct(db, 'product-b');
    await _seedProduct(db, 'product-shared');
    await _seedRawMaterial(db, 'raw-main');
    await _seedRawMaterial(db, 'raw-a');
    await _seedRawMaterial(db, 'raw-shared');
    await _seedCategory(db, 'category-1');
    await _seedAvailability(
      db,
      collection: 'product_branch_availability',
      branchId: 'main',
      itemField: 'productId',
      itemId: 'product-main',
    );
    await _seedAvailability(
      db,
      collection: 'product_branch_availability',
      branchId: 'branch-a',
      itemField: 'productId',
      itemId: 'product-a',
    );
    await _seedAvailability(
      db,
      collection: 'product_branch_availability',
      branchId: 'branch-b',
      itemField: 'productId',
      itemId: 'product-b',
    );
    await _seedInventory(db, 'branch-a', 'product', 'product-shared');
    await _seedAvailability(
      db,
      collection: 'raw_material_branch_availability',
      branchId: 'main',
      itemField: 'rawMaterialId',
      itemId: 'raw-main',
    );
    await _seedAvailability(
      db,
      collection: 'raw_material_branch_availability',
      branchId: 'branch-a',
      itemField: 'rawMaterialId',
      itemId: 'raw-a',
    );
    await _seedInventory(db, 'branch-b', 'raw_material', 'raw-shared');

    expect(await _migrationStateCount(db), 0);
    for (final branchId in _branches) {
      expect(await _branchCollectionIds(db, branchId, 'products'), isEmpty);
      expect(
          await _branchCollectionIds(db, branchId, 'raw_materials'), isEmpty);
      expect(await _branchCollectionIds(db, branchId, 'categories'), isEmpty);
    }

    final service = BranchCatalogMigrationBootstrapService(db);
    await service.runForOwner(merchantId: _merchantId);

    expect(await _branchCollectionIds(db, 'main', 'products'),
        {'product-main', 'product-shared'});
    expect(await _branchCollectionIds(db, 'branch-a', 'products'),
        {'product-a', 'product-shared'});
    expect(
        await _branchCollectionIds(db, 'branch-b', 'products'), {'product-b'});
    expect(await _branchCollectionIds(db, 'main', 'raw_materials'),
        {'raw-main', 'raw-shared'});
    expect(
        await _branchCollectionIds(db, 'branch-a', 'raw_materials'), {'raw-a'});
    expect(await _branchCollectionIds(db, 'branch-b', 'raw_materials'),
        {'raw-shared'});
    for (final branchId in _branches) {
      expect(await _branchCollectionIds(db, branchId, 'categories'),
          {'category-1'});
      for (final prefix in const [
        'legacy_product_visibility_v1_',
        'legacy_raw_material_visibility_v1_',
        'branch_catalog_v1_',
        'branch_raw_materials_v1_',
        'branch_categories_v1_',
      ]) {
        expect(await _migrationStatus(db, '$prefix$branchId'), 'completed');
      }
    }
    expect(await _migrationStateCount(db), 16);

    final countsBeforeRetry = await _catalogCounts(db);
    await service.runForOwner(merchantId: _merchantId);
    expect(await _catalogCounts(db), countsBeforeRetry);
    expect(await _migrationStateCount(db), 16);

    final branchSnapshot = await db
        .collection('merchants')
        .doc(_merchantId)
        .collection('branches')
        .get();
    expect(branchSnapshot.docs.map((doc) => doc.id).toSet(), _branches.toSet());
    expect(
        (await branchSnapshot.docs
                .singleWhere((doc) => doc.id == 'main')
                .reference
                .get())
            .exists,
        isTrue);

    expect(shouldRunBranchCatalogMigrationForRole('employee'), isFalse);
    final stateCountBeforeEmployeeRead = await _migrationStateCount(db);
    final employeeCatalog = await ProductRepository(db)
        .queryProducts(_merchantId, 'branch-a')
        .get();
    expect(employeeCatalog.docs.map((doc) => doc.id).toSet(),
        {'product-a', 'product-shared'});
    expect(await _migrationStateCount(db), stateCountBeforeEmployeeRead);
  });

  test('migration normalizes safe legacy fields and trusts document id',
      () async {
    final db = FakeFirebaseFirestore();
    await _seedBranches(db, branchIds: const ['main']);
    await db.collection('products').doc('canonical-id').set({
      'id': 'stale-stored-id',
      'merchantId': _merchantId,
      'name': 'Legacy product',
      'price': 12,
      'quantity': 99,
      'categoryId': <String, Object?>{'malformed': true},
      'modifiers': <Object?>['Valid', 7, null],
      'recipe': <Object?>[],
      'createdAt': 'not-a-date',
      'updatedAt': null,
    });

    await BranchCatalogMigrationBootstrapService(db)
        .runForOwner(merchantId: _merchantId);

    final migrated = await db
        .collection('merchants')
        .doc(_merchantId)
        .collection('branches')
        .doc('main')
        .collection('products')
        .doc('canonical-id')
        .get();
    expect(migrated.exists, isTrue);
    expect(migrated.data()?['id'], 'canonical-id');
    expect(migrated.data()?['categoryId'], isNull);
    expect(migrated.data()?['modifiers'], ['Valid']);
    expect(migrated.data()?['quantity'], 0);
    expect(migrated.data()?['createdAt'], isA<Timestamp>());
  });

  test('critical legacy failure preserves branch step path and resumes',
      () async {
    final db = FakeFirebaseFirestore();
    await _seedBranches(db, branchIds: const ['main']);
    await _seedProduct(db, 'broken-product', price: 'not-numeric');
    final service = BranchCatalogMigrationBootstrapService(db);

    BranchCatalogMigrationFailure? failure;
    try {
      await service.runForOwner(merchantId: _merchantId);
    } on BranchCatalogMigrationFailure catch (error) {
      failure = error;
    }

    expect(failure, isNotNull);
    expect(failure!.branchId, 'main');
    expect(failure.step, 'product_catalog');
    expect(failure.firestorePath,
        'merchants/$_merchantId/migration_state/branch_catalog_v1_main');
    expect(failure.cause, isA<LegacyCatalogMigrationDataException>());
    final cause = failure.cause as LegacyCatalogMigrationDataException;
    expect(cause.documentPath, 'products/broken-product');
    expect(cause.field, 'price');
    expect(await _migrationStatus(db, 'branch_catalog_v1_main'), isNull);

    await db.collection('products').doc('broken-product').update({'price': 9});
    await service.runForOwner(merchantId: _merchantId);
    expect(await _migrationStatus(db, 'branch_catalog_v1_main'), 'completed');
    expect(
        await _branchCollectionIds(db, 'main', 'products'), {'broken-product'});
  });
}

Future<void> _seedBranches(
  FakeFirebaseFirestore db, {
  List<String> branchIds = _branches,
}) async {
  for (final branchId in branchIds) {
    await db
        .collection('merchants')
        .doc(_merchantId)
        .collection('branches')
        .doc(branchId)
        .set({
      'id': branchId,
      'merchantId': _merchantId,
      'name': branchId,
      'isMain': branchId == 'main',
      'isActive': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }
}

Future<void> _seedProduct(
  FakeFirebaseFirestore db,
  String id, {
  Object price = 10.0,
}) {
  return db.collection('products').doc(id).set({
    'id': id,
    'merchantId': _merchantId,
    'name': id,
    'price': price,
    'quantity': 0,
    'modifiers': <String>[],
    'recipe': <Map<String, Object?>>[],
    'isArchived': false,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> _seedRawMaterial(FakeFirebaseFirestore db, String id) {
  return db.collection('raw_materials').doc(id).set({
    'id': id,
    'merchantId': _merchantId,
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
      .doc(_merchantId)
      .collection('categories')
      .doc(id)
      .set({
    'id': id,
    'merchantId': _merchantId,
    'name': id,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> _seedAvailability(
  FakeFirebaseFirestore db, {
  required String collection,
  required String branchId,
  required String itemField,
  required String itemId,
}) {
  return db
      .collection('merchants')
      .doc(_merchantId)
      .collection(collection)
      .doc('${branchId}_$itemId')
      .set({
    'id': '${branchId}_$itemId',
    'merchantId': _merchantId,
    'branchId': branchId,
    itemField: itemId,
    'enabled': true,
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> _seedInventory(
  FakeFirebaseFirestore db,
  String branchId,
  String itemType,
  String itemId,
) {
  return db
      .collection('merchants')
      .doc(_merchantId)
      .collection('branch_inventory')
      .doc('${branchId}_${itemType}_$itemId')
      .set({
    'id': '${branchId}_${itemType}_$itemId',
    'merchantId': _merchantId,
    'branchId': branchId,
    'itemType': itemType,
    'itemId': itemId,
    'quantity': 5.0,
    'initialQuantity': 5.0,
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<Set<String>> _branchCollectionIds(
  FakeFirebaseFirestore db,
  String branchId,
  String collection,
) async {
  final snapshot = await db
      .collection('merchants')
      .doc(_merchantId)
      .collection('branches')
      .doc(branchId)
      .collection(collection)
      .get();
  return snapshot.docs.map((doc) => doc.id).toSet();
}

Future<String?> _migrationStatus(FakeFirebaseFirestore db, String id) async {
  final snapshot = await db
      .collection('merchants')
      .doc(_merchantId)
      .collection('migration_state')
      .doc(id)
      .get();
  return snapshot.data()?['status']?.toString();
}

Future<int> _migrationStateCount(FakeFirebaseFirestore db) async {
  final snapshot = await db
      .collection('merchants')
      .doc(_merchantId)
      .collection('migration_state')
      .get();
  return snapshot.docs.length;
}

Future<Map<String, int>> _catalogCounts(FakeFirebaseFirestore db) async {
  final counts = <String, int>{};
  for (final branchId in _branches) {
    for (final collection in const [
      'products',
      'raw_materials',
      'categories',
      'legacy_product_visibility',
      'legacy_raw_material_visibility',
    ]) {
      counts['$branchId/$collection'] =
          (await _branchCollectionIds(db, branchId, collection)).length;
    }
  }
  return counts;
}

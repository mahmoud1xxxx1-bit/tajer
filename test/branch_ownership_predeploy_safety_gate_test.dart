import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/branches/data/branch_inventory_repository.dart';
import 'package:tajer/features/branches/data/order_branch_inventory_service.dart';
import 'package:tajer/features/categories/data/category_repository.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/products/data/product_repository.dart';
import 'package:tajer/features/products/data/raw_material_repository.dart';

const merchantId = 'merchant_predeploy';
const branchId = 'branch_2';
const migrationBranchId = 'main';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('branch ownership pre-deploy safety gate', () {
    test('product migration is paginated and never falsely completes at 500',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = ProductRepository(db);
      for (var i = 0; i < 501; i++) {
        await db
            .collection('products')
            .doc('p${i.toString().padLeft(3, '0')}')
            .set(
              _productData(
                id: 'p${i.toString().padLeft(3, '0')}',
                merchantId: merchantId,
              ),
            );
      }
      await repo.buildLegacyProductVisibilityManifestIfNeeded(
        merchantId: merchantId,
        branchId: migrationBranchId,
      );

      await repo.migrateBranchCatalogPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      expect(await _branchProductCount(db), 240);
      final interruptedRead = await repo.readLegacyProductsForBranch(
        merchantId: merchantId,
        branchId: migrationBranchId,
      );
      expect(
          interruptedRead.map((product) => product.id).toSet(), hasLength(501));
      expect(
          await repo.isBranchCatalogMigrationCompleted(
            merchantId: merchantId,
            branchId: migrationBranchId,
          ),
          isFalse);

      await repo.migrateBranchCatalogPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      expect(await _branchProductCount(db), 480);
      expect(
          await repo.isBranchCatalogMigrationCompleted(
            merchantId: merchantId,
            branchId: migrationBranchId,
          ),
          isFalse);

      await repo.migrateBranchCatalogPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      expect(await _branchProductCount(db), 501);
      expect(
          await repo.isBranchCatalogMigrationCompleted(
            merchantId: merchantId,
            branchId: migrationBranchId,
          ),
          isFalse);

      await repo.migrateBranchCatalogPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      expect(
          await repo.isBranchCatalogMigrationCompleted(
            merchantId: merchantId,
            branchId: migrationBranchId,
          ),
          isTrue);
      expect(await _branchProductCount(db), 501);
      final finalBranchProducts = await ProductRepository(db)
          .queryProducts(merchantId, migrationBranchId)
          .get();
      expect(finalBranchProducts.docs.map((doc) => doc.id).toSet(),
          hasLength(501));
    });

    test(
        'raw material migration is paginated and never falsely completes at 500',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = RawMaterialRepository(db);
      for (var i = 0; i < 501; i++) {
        await db
            .collection('raw_materials')
            .doc('r${i.toString().padLeft(3, '0')}')
            .set(_rawMaterialData(
              id: 'r${i.toString().padLeft(3, '0')}',
              merchantId: merchantId,
            ));
      }

      await repo.migrateBranchRawMaterialsPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      expect(await _branchRawMaterialCount(db), 240);
      expect(
          await repo.isBranchRawMaterialMigrationCompleted(
            merchantId: merchantId,
            branchId: migrationBranchId,
          ),
          isFalse);

      await repo.migrateBranchRawMaterialsPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      await repo.migrateBranchRawMaterialsPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      await repo.migrateBranchRawMaterialsPage(
        merchantId: merchantId,
        branchId: migrationBranchId,
        pageSize: 400,
      );
      expect(await _branchRawMaterialCount(db), 501);
      expect(
          await repo.isBranchRawMaterialMigrationCompleted(
            merchantId: merchantId,
            branchId: migrationBranchId,
          ),
          isTrue);
    });

    test('category migration is paginated and never falsely completes at 500',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = CategoryRepository(db, merchantId, migrationBranchId);
      for (var i = 0; i < 501; i++) {
        await db
            .collection('merchants')
            .doc(merchantId)
            .collection('categories')
            .doc('c${i.toString().padLeft(3, '0')}')
            .set({
          'id': 'c${i.toString().padLeft(3, '0')}',
          'merchantId': merchantId,
          'name': 'Category $i',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
      }

      await repo.migrateBranchCategoriesPage(pageSize: 400);
      expect(await _branchCategoryCount(db), 400);
      expect(await repo.isBranchCategoryMigrationCompleted(), isFalse);

      await repo.migrateBranchCategoriesPage(pageSize: 400);
      await repo.migrateBranchCategoriesPage(pageSize: 400);
      expect(await _branchCategoryCount(db), 501);
      expect(await repo.isBranchCategoryMigrationCompleted(), isTrue);
    });

    test('runtime streams do not trigger branch catalog migrations', () {
      expect(
        File('lib/features/products/data/product_repository.dart')
            .readAsStringSync(),
        isNot(contains('.migrateBranchCatalogIfNeeded(')),
      );
      expect(
        File('lib/features/products/data/raw_material_repository.dart')
            .readAsStringSync(),
        isNot(contains('.migrateBranchRawMaterialsIfNeeded(')),
      );
      expect(
        File('lib/features/categories/data/category_repository.dart')
            .readAsStringSync(),
        isNot(contains('.migrateBranchCategoriesIfNeeded(')),
      );
    });

    test('transfer operation id is idempotent and conflicting retries fail',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = BranchInventoryRepository(db, merchantId);
      await repo.setQuantity(
        branchId: 'a',
        itemType: 'product',
        itemId: 'source',
        quantity: 10,
        initialQuantity: 10,
      );
      await repo.setQuantity(
        branchId: 'b',
        itemType: 'product',
        itemId: 'dest',
        quantity: 0,
        initialQuantity: 0,
      );

      await repo.transferQuantity(
        fromBranchId: 'a',
        toBranchId: 'b',
        itemType: 'product',
        itemId: 'source',
        destinationItemId: 'dest',
        operationId: 'transfer-op',
        itemName: 'Pepsi',
        quantity: 3,
      );
      await repo.transferQuantity(
        fromBranchId: 'a',
        toBranchId: 'b',
        itemType: 'product',
        itemId: 'source',
        destinationItemId: 'dest',
        operationId: 'transfer-op',
        itemName: 'Pepsi',
        quantity: 3,
      );

      expect(
          (await repo.getItem(
                  branchId: 'a', itemType: 'product', itemId: 'source'))!
              .quantity,
          7);
      expect(
          (await repo.getItem(
                  branchId: 'b', itemType: 'product', itemId: 'dest'))!
              .quantity,
          3);
      final logs = await db
          .collection('merchants')
          .doc(merchantId)
          .collection('inventory_logs')
          .where('transferId', isEqualTo: 'transfer-op')
          .get();
      expect(logs.docs, hasLength(2));

      expect(
        () => repo.transferQuantity(
          fromBranchId: 'a',
          toBranchId: 'b',
          itemType: 'product',
          itemId: 'source',
          destinationItemId: 'dest',
          operationId: 'transfer-op',
          itemName: 'Pepsi',
          quantity: 4,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('concurrent duplicate transfer operation writes one transfer and logs',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = BranchInventoryRepository(db, merchantId);
      await repo.setQuantity(
        branchId: 'a',
        itemType: 'product',
        itemId: 'source',
        quantity: 10,
        initialQuantity: 10,
      );
      await repo.setQuantity(
        branchId: 'b',
        itemType: 'product',
        itemId: 'dest',
        quantity: 0,
        initialQuantity: 0,
      );

      await Future.wait([
        repo.transferQuantity(
          fromBranchId: 'a',
          toBranchId: 'b',
          itemType: 'product',
          itemId: 'source',
          destinationItemId: 'dest',
          operationId: 'concurrent-op',
          itemName: 'Pepsi',
          quantity: 3,
        ),
        repo.transferQuantity(
          fromBranchId: 'a',
          toBranchId: 'b',
          itemType: 'product',
          itemId: 'source',
          destinationItemId: 'dest',
          operationId: 'concurrent-op',
          itemName: 'Pepsi',
          quantity: 3,
        ),
      ]);

      expect(
          (await repo.getItem(
                  branchId: 'a', itemType: 'product', itemId: 'source'))!
              .quantity,
          7);
      expect(
          (await repo.getItem(
                  branchId: 'b', itemType: 'product', itemId: 'dest'))!
              .quantity,
          3);
      final transfers = await db
          .collection('merchants')
          .doc(merchantId)
          .collection('inventory_transfers')
          .where('id', isEqualTo: 'concurrent-op')
          .get();
      final logs = await db
          .collection('merchants')
          .doc(merchantId)
          .collection('inventory_logs')
          .where('transferId', isEqualTo: 'concurrent-op')
          .get();
      expect(transfers.docs, hasLength(1));
      expect(logs.docs, hasLength(2));
    });

    test('legacy product fallback requires branch ownership evidence',
        () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('products')
          .doc('pepsi')
          .set(_productData(id: 'pepsi', merchantId: merchantId, quantity: 27));
      final order = _order(branchId: branchId);

      await expectLater(
        OrderBranchInventoryService(db).applySale(order, queueNumber: 1),
        throwsA(isA<Exception>()),
      );

      await BranchInventoryRepository(db, merchantId).setQuantity(
        branchId: branchId,
        itemType: 'product',
        itemId: 'pepsi',
        quantity: 10,
        initialQuantity: 10,
      );
      await OrderBranchInventoryService(db).applySale(order, queueNumber: 2);
      final item = await BranchInventoryRepository(db, merchantId).getItem(
        branchId: branchId,
        itemType: 'product',
        itemId: 'pepsi',
      );
      expect(item!.quantity, 8);
    });

    test('legacy raw fallback cannot consume branch A material from branch B',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('products').doc('burger').set(_productData(
            id: 'burger',
            merchantId: merchantId,
            recipe: const [
              {'rawMaterialId': 'bun', 'amountRequired': 2.0},
            ],
            isManufacturedOnDemand: true,
          ));
      await db.collection('raw_materials').doc('bun').set(
            _rawMaterialData(id: 'bun', merchantId: merchantId),
          );
      await db
          .collection('merchants')
          .doc(merchantId)
          .collection('product_branch_availability')
          .doc('branch_b_burger')
          .set({
        'id': 'branch_b_burger',
        'merchantId': merchantId,
        'branchId': 'branch_b',
        'productId': 'burger',
        'enabled': true,
      });
      await BranchInventoryRepository(db, merchantId).setQuantity(
        branchId: 'branch_a',
        itemType: 'raw_material',
        itemId: 'bun',
        quantity: 10,
        initialQuantity: 10,
      );

      await expectLater(
        OrderBranchInventoryService(db).applySale(
            _order(branchId: 'branch_b', productId: 'burger'),
            queueNumber: 3),
        throwsA(predicate((error) =>
            error.toString().contains('Insufficient raw material inventory'))),
      );
    });

    test('main legacy fallback and migrated branch item remain valid',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('products').doc('main_pepsi').set(
          _productData(id: 'main_pepsi', merchantId: merchantId, quantity: 5));
      await OrderBranchInventoryService(db).applySale(
        _order(branchId: 'main', productId: 'main_pepsi'),
        queueNumber: 4,
      );
      final mainItem = await BranchInventoryRepository(db, merchantId).getItem(
        branchId: 'main',
        itemType: 'product',
        itemId: 'main_pepsi',
      );
      expect(mainItem!.quantity, 3);

      await db
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .doc('branch_pepsi')
          .set(_productData(
              id: 'branch_pepsi', merchantId: merchantId, quantity: 0));
      await BranchInventoryRepository(db, merchantId).setQuantity(
        branchId: branchId,
        itemType: 'product',
        itemId: 'branch_pepsi',
        quantity: 6,
        initialQuantity: 6,
      );
      await OrderBranchInventoryService(db).applySale(
        _order(branchId: branchId, productId: 'branch_pepsi'),
        queueNumber: 5,
      );
      final branchItem =
          await BranchInventoryRepository(db, merchantId).getItem(
        branchId: branchId,
        itemType: 'product',
        itemId: 'branch_pepsi',
      );
      expect(branchItem!.quantity, 4);
    });
  });
}

Future<int> _branchProductCount(FakeFirebaseFirestore db) async {
  final snap = await db
      .collection('merchants')
      .doc(merchantId)
      .collection('branches')
      .doc(migrationBranchId)
      .collection('products')
      .get();
  return snap.docs.length;
}

Future<int> _branchRawMaterialCount(FakeFirebaseFirestore db) async {
  final snap = await db
      .collection('merchants')
      .doc(merchantId)
      .collection('branches')
      .doc(migrationBranchId)
      .collection('raw_materials')
      .get();
  return snap.docs.length;
}

Future<int> _branchCategoryCount(FakeFirebaseFirestore db) async {
  final snap = await db
      .collection('merchants')
      .doc(merchantId)
      .collection('branches')
      .doc(migrationBranchId)
      .collection('categories')
      .get();
  return snap.docs.length;
}

Map<String, Object?> _productData({
  required String id,
  required String merchantId,
  int quantity = 0,
  List<Map<String, Object?>> recipe = const <Map<String, Object?>>[],
  bool isManufacturedOnDemand = false,
}) {
  return {
    'id': id,
    'merchantId': merchantId,
    'name': 'Pepsi',
    'categoryId': null,
    'barcode': null,
    'price': 20.0,
    'quantity': quantity,
    'modifiers': <String>[],
    'recipe': recipe,
    'isTaxInclusive': null,
    'taxPercentage': null,
    'isManufacturedOnDemand': isManufacturedOnDemand,
    'isArchived': false,
    'taxMode': 'store',
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  };
}

Map<String, Object?> _rawMaterialData({
  required String id,
  required String merchantId,
}) {
  return {
    'id': id,
    'merchantId': merchantId,
    'name': 'Sugar',
    'quantity': 0.0,
    'initialQuantity': 0.0,
    'unit': 'g',
    'isArchived': false,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  };
}

AppOrder _order({required String branchId, String productId = 'pepsi'}) {
  return AppOrder(
    id: 'order_1',
    merchantId: merchantId,
    branchId: branchId,
    customerId: 'walk_in',
    customerName: 'Walk-in',
    items: [
      CartItem(
        productId: productId,
        productName: 'Pepsi',
        quantity: 2,
        price: 20,
        total: 40,
      ),
    ],
    total: 40,
    createdAt: DateTime(2026, 1, 1),
  );
}

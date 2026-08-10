import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/services/app_failure.dart';
import 'package:tajer/core/services/app_error_mapper.dart';

void main() {
  group('branch ownership foundation contracts', () {
    late String productRepository;
    late String rawMaterialRepository;
    late String addProductDialog;
    late String rawMaterialsScreen;
    late String productsScreen;
    late String rules;

    setUpAll(() {
      productRepository =
          File('lib/features/products/data/product_repository.dart')
              .readAsStringSync();
      rawMaterialRepository =
          File('lib/features/products/data/raw_material_repository.dart')
              .readAsStringSync();
      addProductDialog =
          File('lib/features/products/presentation/add_product_dialog.dart')
              .readAsStringSync();
      rawMaterialsScreen =
          File('lib/features/products/presentation/raw_materials_screen.dart')
              .readAsStringSync();
      productsScreen =
          File('lib/features/products/presentation/products_screen.dart')
              .readAsStringSync();
      rules = File('firestore.rules').readAsStringSync();
    });

    test('products are branch-owned at runtime', () {
      expect(productRepository, contains('collection(\'branches\')'));
      expect(productRepository, contains('collection(\'products\')'));
      expect(productRepository, contains('migrateBranchCatalogIfNeeded'));
      expect(addProductDialog, isNot(contains('Available in branches')));
      expect(addProductDialog, isNot(contains('setProductAvailability')));
    });

    test('product mutations capture immutable branch operation context', () {
      expect(addProductDialog, contains('final capturedBranchId'));
      expect(addProductDialog, contains('BranchOperationContext('));
      expect(addProductDialog, contains('branchId: operationContext.branchId'));
      expect(addProductDialog, isNot(contains('deleteProduct(product.id)')));
    });

    test('new products write only the captured branch catalog', () {
      expect(addProductDialog, contains('final capturedBranchId'));
      expect(addProductDialog,
          contains('enabledBranchIds: {operationContext.branchId}'));
      expect(
          productRepository, contains("data['branchId'] = context.branchId"));
      expect(addProductDialog, isNot(contains('_selectedBranchIds')));
    });

    test('raw materials are branch-owned and recipes validate same branch', () {
      expect(rawMaterialRepository, contains('collection(\'branches\')'));
      expect(rawMaterialRepository, contains('collection(\'raw_materials\')'));
      expect(rawMaterialRepository, contains('existsInBranch'));
      expect(addProductDialog, contains('rawMaterialRepo.existsInBranch'));
      expect(rawMaterialsScreen, contains('BranchOperationContext('));
      expect(rawMaterialsScreen, isNot(contains('setRawMaterialAvailability')));
    });

    test('remove from branch and global archive are distinct awaited actions',
        () {
      expect(productsScreen, contains("value: 'remove_branch'"));
      expect(productsScreen, contains("value: 'archive_store'"));
      expect(productsScreen, contains('await repo.removeProductFromBranch'));
      expect(productsScreen, contains('await repo.archiveProductFromStore'));
      expect(productsScreen, contains('if (policy.isOwnerLike)'));
    });

    test('rules scope branch catalogs by merchant, branch and permission', () {
      expect(rules, contains('match /branches/{branchId}'));
      expect(rules, contains('match /products/{productId}'));
      expect(rules, contains('match /categories/{categoryId}'));
      expect(rules, contains('match /raw_materials/{materialId}'));
      expect(
          rules, contains("hasPermission(merchantId, 'can_manage_products')"));
      expect(
          rules, contains("hasPermission(merchantId, 'can_manage_inventory')"));
      expect(rules, isNot(contains('allow read, write: if true')));
    });
  });

  group('typed employee login failures', () {
    test('known employee failures map without raw substring guessing', () {
      final invalid = AppErrorMapper.fromError(
        const EmployeeLoginFailure(AppFailureKind.invalidCredentials),
      );
      final deleted = AppErrorMapper.fromError(
        const EmployeeLoginFailure(AppFailureKind.employeeDeleted),
      );

      expect(invalid.titleEn, 'Invalid sign-in details');
      expect(deleted.titleEn, 'Account unavailable');
      expect(invalid.messageEn, isNot(contains('Exception')));
      expect(deleted.messageEn, isNot(contains('permission-denied')));
    });
  });
}

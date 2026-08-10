import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/services/app_failure.dart';
import 'package:tajer/core/services/app_error_mapper.dart';

void main() {
  group('branch availability foundation contracts', () {
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

    test('product availability is branch membership, not product duplication',
        () {
      expect(productRepository, contains('product_branch_availability'));
      expect(productRepository,
          contains('watchAvailability(merchantId, branchId)'));
      expect(productRepository, contains("return branchId == 'main' ||"));
      expect(productRepository,
          contains('inventoryEvidence.contains(product.id)'));
      expect(productRepository, isNot(contains(r'products_${branchId}')));
    });

    test('product mutations capture immutable branch operation context', () {
      expect(addProductDialog, contains('final capturedBranchId'));
      expect(addProductDialog, contains('BranchOperationContext('));
      expect(addProductDialog, contains('branchId: operationContext.branchId'));
      expect(addProductDialog, isNot(contains('deleteProduct(product.id)')));
    });

    test('new products write explicit false membership for unselected branches',
        () {
      expect(addProductDialog, contains('Available in branches'));
      expect(addProductDialog, contains('<String>{activeBranchId}'));
      expect(addProductDialog, contains('knownBranchIds: knownBranchIds'));
      expect(productRepository,
          contains("'enabled': enabledBranchIds.contains(branchId)"));
    });

    test('raw material branch availability protects recipe branch integrity',
        () {
      expect(
          rawMaterialRepository, contains('raw_material_branch_availability'));
      expect(rawMaterialRepository, contains('isAvailableInBranch'));
      expect(addProductDialog, contains('rawMaterialRepo.isAvailableInBranch'));
      expect(rawMaterialsScreen, contains('BranchOperationContext('));
      expect(rawMaterialsScreen, contains('knownBranchIds: knownBranchIds'));
    });

    test('remove from branch and global archive are distinct awaited actions',
        () {
      expect(productsScreen, contains("value: 'remove_branch'"));
      expect(productsScreen, contains("value: 'archive_store'"));
      expect(productsScreen, contains('await repo.removeProductFromBranch'));
      expect(productsScreen, contains('await repo.archiveProductFromStore'));
      expect(productsScreen, contains('if (policy.isOwnerLike)'));
    });

    test('rules scope availability by merchant, branch and permission', () {
      expect(rules,
          contains('match /product_branch_availability/{availabilityId}'));
      expect(
          rules, contains("hasPermission(merchantId, 'can_manage_products')"));
      expect(rules,
          contains('match /raw_material_branch_availability/{availabilityId}'));
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

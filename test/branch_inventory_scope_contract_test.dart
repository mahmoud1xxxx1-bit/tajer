import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Branch inventory scope contract', () {
    test('branch-aware checkout uses branch inventory service and not legacy createOrder', () {
      final source = File(
        'lib/features/orders/data/branch_aware_order_repository.dart',
      ).readAsStringSync();

      expect(source, contains('OrderBranchInventoryService(firestore)'));
      expect(source, contains('.applySaleInTransaction('));
      expect(source, contains('runTransaction<AppOrder>'));
      expect(source, isNot(contains('super.createOrder(')));
    });

    test('product list resolves quantity from selected branch inventory', () {
      final source = File(
        'lib/features/products/data/product_repository.dart',
      ).readAsStringSync();

      expect(source, contains('selectedBranchIdProvider'));
      expect(source, contains('branchInventoryStreamProvider(branchId)'));
      expect(source, contains("item.itemType == 'product'"));
      expect(source, contains('queryProducts(String merchantId, String branchId)'));
      expect(source, contains("collection('branches')"));

      // Branch-owned catalog identity is independent from branch stock. Stock
      // is still overlaid from branch_inventory and defaults to zero when no
      // inventory row exists.
      expect(source, contains('final scopedQuantity = quantities[product.id];'));
      expect(source, contains('product.copyWith(quantity: (scopedQuantity ?? 0).round())'));

      // Cost visibility is orthogonal to branch stock and must come only from
      // the protected product_costs stream for authorized users.
      expect(source, contains("appUser.hasPermission('can_view_cost')"));
      expect(source, contains('productCostsStreamProvider(merchantId)'));
      expect(source, contains('next = next.copyWith(costPrice: cost);'));
    });

    test('raw materials resolve quantity from selected branch inventory', () {
      final source = File(
        'lib/features/products/data/raw_material_repository.dart',
      ).readAsStringSync();

      expect(source, contains('selectedBranchIdProvider'));
      expect(source, contains('branchInventoryStreamProvider(branchId)'));
      expect(source, contains("item.itemType == 'raw_material'"));
      expect(source, contains('watchRawMaterials(merchantId, branchId)'));
      expect(source, contains("collection('branches')"));
      expect(
        source,
        contains('return material.copyWith(quantity: 0.0, initialQuantity: 0.0);'),
      );
    });

    test('recipe consumption is branch-scoped and manufactured-on-demand skips finished stock', () {
      final source = File(
        'lib/features/branches/data/order_branch_inventory_service.dart',
      ).readAsStringSync();

      expect(source, contains("data['isManufacturedOnDemand']"));
      expect(source, contains("itemType: 'product'"));
      expect(source, contains("itemType: 'raw_material'"));
      expect(source, contains('amount * item.quantity'));
      expect(source, contains("'branchId': order.branchId"));
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Branch inventory scope contract', () {
    test('branch-aware checkout uses branch inventory service and not legacy createOrder', () {
      final source = File(
        'lib/features/orders/data/branch_aware_order_repository.dart',
      ).readAsStringSync();

      expect(source, contains('OrderBranchInventoryService(firestore)'));
      expect(source, contains('.applySale(orderWithQueue'));
      expect(source, isNot(contains('super.createOrder(')));
    });

    test('product list resolves quantity from selected branch inventory', () {
      final source = File(
        'lib/features/products/data/product_repository.dart',
      ).readAsStringSync();

      expect(source, contains('selectedBranchIdProvider'));
      expect(source, contains('branchInventoryStreamProvider(branchId)'));
      expect(source, contains("item.itemType == 'product'"));
      expect(source, contains("if (branchId == 'main') return product;"));
      expect(source, contains('return product.copyWith(quantity: 0);'));
    });

    test('raw materials resolve quantity from selected branch inventory', () {
      final source = File(
        'lib/features/products/data/raw_material_repository.dart',
      ).readAsStringSync();

      expect(source, contains('selectedBranchIdProvider'));
      expect(source, contains('branchInventoryStreamProvider(branchId)'));
      expect(source, contains("item.itemType == 'raw_material'"));
      expect(source, contains("if (branchId == 'main') return material;"));
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

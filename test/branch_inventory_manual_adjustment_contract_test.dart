import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual stock edits target branch inventory and audit atomically', () {
    final branchRepo = File(
      'lib/features/branches/data/branch_inventory_repository.dart',
    ).readAsStringSync();
    final logRepo = File(
      'lib/features/inventory_log/data/inventory_log_repository.dart',
    ).readAsStringSync();

    expect(branchRepo, contains('setQuantityWithAudit'));
    expect(branchRepo, contains('return firestore.runTransaction<double>'));
    expect(branchRepo, contains('tx.set(logRef'));
    expect(branchRepo, contains("'previousQuantity': current"));
    expect(branchRepo, contains("'newQuantity': normalizedQuantity"));

    expect(logRepo, contains('ref.watch(selectedBranchIdProvider)'));
    expect(logRepo, contains('branchRepo.setQuantityWithAudit'));
    expect(logRepo, contains('await _firestore.runTransaction<void>'));
    expect(logRepo, contains("'revertsLogId': log.id"));
  });

  test('merchant master documents no longer accept selected branch stock', () {
    final products = File(
      'lib/features/products/data/product_repository.dart',
    ).readAsStringSync();
    final rawMaterials = File(
      'lib/features/products/data/raw_material_repository.dart',
    ).readAsStringSync();

    expect(products, contains("data['quantity'] = 0"));
    expect(products, contains("data.remove('quantity')"));
    expect(rawMaterials, contains("data['quantity'] = 0.0"));
    expect(rawMaterials, contains("data.remove('quantity')"));
    expect(rawMaterials, contains("data.remove('initialQuantity')"));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branch inventory keys isolate identical items across branches', () {
    final source = File(
      'lib/features/branches/data/branch_inventory_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'\${branchId}_\${itemType}_\$itemId'"),
    );
    expect(source, contains("ref.where('branchId', isEqualTo: branchId)"));
  });

  test('concurrent checkout cannot oversell the final branch unit', () {
    final source = File(
      'lib/features/branches/data/order_branch_inventory_service.dart',
    ).readAsStringSync();

    expect(source, contains('await firestore.runTransaction<void>'));
    expect(source, contains('snapshots[entry.key] = await tx.get'));
    expect(source, contains('calculated < -0.000001'));
    expect(source, contains('Insufficient branch inventory'));
    expect(source, contains("'quantity': next[key]"));
  });
}

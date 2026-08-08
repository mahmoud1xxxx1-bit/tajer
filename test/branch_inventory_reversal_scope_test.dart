import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory reversals always use the order original branch', () {
    final service = File(
      'lib/features/branches/data/order_branch_inventory_service.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/orders/data/branch_aware_order_repository.dart',
    ).readAsStringSync();
    final orderModel = File(
      'lib/features/orders/domain/order.dart',
    ).readAsStringSync();

    // v107 orders with no branchId must resolve to Main Branch.
    expect(orderModel, contains("branchId: json['branchId']?.toString() ?? 'main'"));

    // Every sale/cancel/delete/reversal inventory mutation is scoped from the
    // immutable order snapshot, never from the branch currently selected in UI.
    expect(service, contains('order.branchId'));
    expect(
      service,
      contains('repository.docId(\n          order.branchId,'),
    );
    expect(service, isNot(contains('selectedBranchIdProvider')));
    expect(service, isNot(contains("selected_branch_")));

    expect(
      repository,
      contains('restoreForCancellation(order)'),
    );
    expect(
      repository,
      contains('reDeductAfterCancellationReversal(order)'),
    );
    expect(
      repository,
      contains('restoreForDeletion(order)'),
    );
  });
}

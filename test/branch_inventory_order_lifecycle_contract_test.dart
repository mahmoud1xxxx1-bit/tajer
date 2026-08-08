import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancel delete and restore inventory use the order originating branch', () {
    final service = File(
      'lib/features/branches/data/order_branch_inventory_service.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/orders/data/branch_aware_order_repository.dart',
    ).readAsStringSync();

    // Inventory mutation scope must come from the persisted order itself, never
    // from the branch currently selected on the device when an old invoice is
    // cancelled, deleted, or restored.
    expect(service, contains('order.branchId'));
    expect(service, contains("order.branchId == 'main'"));
    expect(service, isNot(contains('selectedBranchIdProvider')));
    expect(service, isNot(contains("selected_branch_")));

    expect(repository, contains('.restoreForCancellation(order)'));
    expect(repository, contains('.reDeductAfterCancellationReversal(order)'));
    expect(repository, contains('.restoreForDeletion(order)'));

    // A cancelled order already had its stock restored, so permanent deletion
    // must not restore it a second time.
    expect(repository, contains("if (order.status != 'cancelled')"));

    // Status transition claim prevents two devices from applying the same
    // cancellation/reversal inventory mutation concurrently.
    expect(repository, contains('_claimStatusTransition(order, newStatus)'));
    expect(repository, contains("data['statusTransition'] != null"));
  });
}

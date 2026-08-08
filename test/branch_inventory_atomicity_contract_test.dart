import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branch inventory mutation and audit log share one transaction', () {
    final source = File(
      'lib/features/branches/data/order_branch_inventory_service.dart',
    ).readAsStringSync();

    expect(source, contains('firestore.runTransaction<void>'));
    expect(source, contains('tx.set(logRef'));
    expect(source, contains("'previousQuantity': previous[key]"));
    expect(source, contains("'newQuantity': next[key]"));

    // A separate batch plus compensating rollback creates a race window under
    // concurrent cashiers. The inventory mutation and its audit trail must stay
    // inside the same Firestore transaction.
    expect(source, isNot(contains('firestore.batch()')));
    expect(source, isNot(contains('final rollback =')));
  });

  test('checkout persists order, stock, customer and shift in one transaction',
      () {
    final repository = File(
      'lib/features/orders/data/branch_aware_order_repository.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/branches/data/order_branch_inventory_service.dart',
    ).readAsStringSync();

    expect(repository, contains('runTransaction<AppOrder>'));
    expect(
        repository, contains('final existingOrder = await tx.get(orderRef)'));
    expect(repository, contains('return AppOrder.fromJson(existingData)'));
    expect(repository, contains('applySaleInTransaction('));
    expect(repository, contains('tx.set(orderRef, orderWithQueue.toJson())'));
    expect(repository, contains("order.copyWith("));
    expect(repository, contains("shiftId: shiftId"));

    expect(
      service,
      contains('Future<void> applySaleInTransaction('),
    );
    expect(service, contains('Transaction tx'));
    expect(service, contains("productSnaps.add(await tx.get"));
    expect(service, contains("rawSnaps.add(await tx.get"));
  });
}

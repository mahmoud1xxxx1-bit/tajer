import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branch inventory mutation and audit log share one transaction', () {
    final source = File(
      'lib/features/branches/data/order_branch_inventory_service.dart',
    ).readAsStringSync();

    expect(source, contains('await firestore.runTransaction<void>'));
    expect(source, contains('tx.set(logRef'));
    expect(source, contains("'previousQuantity': previous[key]"));
    expect(source, contains("'newQuantity': next[key]"));

    // A separate batch plus compensating rollback creates a race window under
    // concurrent cashiers. The inventory mutation and its audit trail must stay
    // inside the same Firestore transaction.
    expect(source, isNot(contains('firestore.batch()')));
    expect(source, isNot(contains('final rollback =')));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data migration rolls write batches after every commit', () {
    final source = File('lib/core/services/data_migration_service.dart')
        .readAsStringSync();

    expect(source, contains('var batch = _firestore.batch();'));
    expect(source, contains('Future<void> flushBatchIfNeeded'));
    expect(source, contains('batch = _firestore.batch();'));
    expect(source, contains('await flushBatchIfNeeded(force: true);'));
    expect(source, isNot(contains('final batch = _firestore.batch();')));
    expect(source, isNot(contains('operationCount += 2')));
  });
}

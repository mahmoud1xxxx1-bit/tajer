import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trusted COGS backend contract', () {
    late String functionSource;
    late String firebaseConfig;

    setUpAll(() {
      functionSource = File('functions/index.js').readAsStringSync();
      firebaseConfig = File('firebase.json').readAsStringSync();
    });

    test('order creation trigger captures cost from protected product costs',
        () {
      expect(functionSource, contains("document: 'orders/{orderId}'"));
      expect(functionSource, contains("collection('product_costs')"));
      expect(functionSource, contains("collection('order_cost_snapshots')"));
      expect(functionSource, contains("source: 'trusted_server_trigger'"));
    });

    test('client supplied order cost is never trusted by backend snapshot', () {
      expect(functionSource, isNot(contains("item?.costPrice")));
      expect(functionSource, contains('costs.get(productId)'));
    });

    test(
        'incomplete authoritative cost fails closed instead of reporting partial profit',
        () {
      expect(functionSource, contains('isComplete: complete'));
      expect(functionSource,
          contains('totalCost: complete ? calculatedTotalCost : null'));
    });

    test('trigger is idempotent for at-least-once delivery', () {
      expect(functionSource, contains('if (existing.exists) return;'));
      expect(functionSource, contains('await targetRef.create'));
      expect(functionSource, contains("error.code === 'already-exists'"));
      expect(functionSource, contains('error.code === 6'));
    });

    test('firebase deployment configuration registers functions source', () {
      expect(firebaseConfig, contains('"functions"'));
      expect(firebaseConfig, contains('"source": "functions"'));
      expect(firebaseConfig, contains('"runtime": "nodejs20"'));
    });
  });
}

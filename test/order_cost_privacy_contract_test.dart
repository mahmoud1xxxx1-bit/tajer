import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';

void main() {
  test('public cart/order serialization never exposes costPrice', () {
    const item = CartItem(
      productId: 'p1',
      productName: 'Coffee',
      quantity: 2,
      price: 20,
      total: 40,
      costPrice: 7.5,
    );

    expect(item.toJson()['costPrice'], 7.5);
    expect(item.toPublicJson().containsKey('costPrice'), isFalse);

    final order = AppOrder(
      id: 'o1',
      merchantId: 'm1',
      branchId: 'main',
      customerId: 'walk_in',
      customerName: 'Walk in',
      items: const [item],
      total: 40,
      createdAt: DateTime(2026, 8, 8),
    );

    final serializedItems = order.toJson()['items'] as List<dynamic>;
    expect((serializedItems.single as Map).containsKey('costPrice'), isFalse);
  });

  test('legacy order cost migration is separate and removes public field', () {
    final source = File(
      'lib/features/orders/data/order_cost_snapshot_repository.dart',
    ).readAsStringSync();

    expect(source, contains("collection('order_cost_snapshots')"));
    expect(source, contains("item.remove('costPrice')"));
    expect(source, contains("batch.update(orderDoc.reference, {'items': publicItems})"));
    expect(source, contains("'totalCost': totalCost"));
  });
}

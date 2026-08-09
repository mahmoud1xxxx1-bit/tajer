import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';

void main() {
  test('cart/order serialization preserves v107 historical cost snapshot', () {
    const item = CartItem(
      productId: 'p1',
      productName: 'Coffee',
      quantity: 2,
      price: 20,
      total: 40,
      costPrice: 7.5,
      isManufacturedOnDemand: true,
    );

    expect(item.toJson()['costPrice'], 7.5);
    expect(item.toPublicJson()['costPrice'], 7.5);
    expect(item.toPublicJson()['isManufacturedOnDemand'], isTrue);

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
    expect((serializedItems.single as Map)['costPrice'], 7.5);
    expect((serializedItems.single as Map)['isManufacturedOnDemand'], isTrue);
  });

  test(
      'legacy order cost migration is separate, fail-closed and removes public field',
      () {
    final source = File(
      'lib/features/orders/data/order_cost_snapshot_repository.dart',
    ).readAsStringSync();

    expect(source, contains("collection('order_cost_snapshots')"));
    expect(source, contains("item.remove('costPrice')"));
    expect(source,
        contains("batch.update(orderDoc.reference, {'items': publicItems})"));

    // Migration must not publish a partial COGS total as if it were complete.
    expect(
        source, contains("'totalCost': complete ? calculatedTotalCost : null"));
    expect(source, contains("'isComplete': complete"));
    expect(source, contains("'unitCost': null"));
    expect(source, contains("'lineCost': null"));
  });
}

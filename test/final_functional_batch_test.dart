import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/products/domain/product.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';

void main() {
  group('F3: Low Stock Threshold', () {
    test('Product model supports lowStockThreshold', () {
      final product = Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Test Product',
        price: 10,
        quantity: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lowStockThreshold: 15,
      );

      final json = product.toJson();
      expect(json['lowStockThreshold'], 15);

      final parsed = Product.fromJson(json);
      expect(parsed.lowStockThreshold, 15);
    });
  });

  group('F5: Invoice-Level Discounts', () {
    test('CartItem and AppOrder models support discount fields', () {
      final item = CartItem(
        productId: 'p1',
        productName: 'P1',
        quantity: 2,
        price: 50.0,
        total: 100.0,
        discountType: 'percentage',
        discountValue: 10.0,
        discountAmount: 10.0, // (10% of 100)
      );

      final order = AppOrder(
        id: 'o1',
        merchantId: 'm1',
        customerId: 'c1',
        customerName: 'Customer',
        total: 90.0,
        items: [item],
        createdAt: DateTime.now(),
        discountType: 'percentage',
        discountValue: 10.0,
        discountAmount: 10.0,
      );

      final orderJson = order.toJson();
      expect(orderJson['discountType'], 'percentage');
      expect(orderJson['discountValue'], 10.0);
      expect(orderJson['discountAmount'], 10.0);
      
      final itemJson = orderJson['items'][0];
      expect(itemJson['discountType'], 'percentage');
      expect(itemJson['discountValue'], 10.0);
      expect(itemJson['discountAmount'], 10.0);

      final parsedOrder = AppOrder.fromJson(orderJson);
      expect(parsedOrder.discountAmount, 10.0);
      expect(parsedOrder.items.first.discountAmount, 10.0);
    });
  });
}

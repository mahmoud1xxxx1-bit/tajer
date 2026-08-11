import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/products/domain/product.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  AppOrder makeOrder(String id, List<CartItem> items, double total) => AppOrder(
        id: id,
        merchantId: 'm1',
        branchId: 'main',
        customerId: 'walk_in',
        customerName: 'Walk in',
        items: items,
        total: total,
        paymentMethod: 'cash',
        paidAmount: total,
        createdAt: DateTime(2026, 8, 11),
      );

  ReportsService report(AppOrder order, {double defaultTax = 15}) => ReportsService(
        [order],
        const [],
        const [],
        const [],
        const [],
        protectedOrderCosts: {order.id: 0},
        defaultTaxPercentage: defaultTax,
        defaultIsTaxInclusive: true,
      );

  test('mixed exempt, store-default and custom VAT lines reconcile independently', () {
    final exempt = CartItem(
      productId: 'e', productName: 'Exempt', quantity: 1,
      price: 100, total: 100, taxMode: TaxMode.exempt,
      taxPercentage: null, isTaxInclusive: true,
    );
    final store = CartItem(
      productId: 's', productName: 'Store', quantity: 1,
      price: 115, total: 115, taxMode: TaxMode.storeDefault,
      taxPercentage: null, isTaxInclusive: true,
    );
    final custom = CartItem(
      productId: 'c', productName: 'Custom', quantity: 1,
      price: 105, total: 105, taxMode: TaxMode.custom,
      taxPercentage: 5, isTaxInclusive: true,
    );
    final r = report(makeOrder('mixed', [exempt, store, custom], 320));
    expect(r.totalTaxCollected, closeTo(20, 0.000001));
    expect(r.netSalesRevenue, closeTo(300, 0.000001));
  });

  test('multiple quantities and discount keep taxable base and gross aligned', () {
    final line = CartItem(
      productId: 'q', productName: 'Qty', quantity: 3,
      price: 38.3333333333, total: 115,
      discountAmount: 11.5,
      taxMode: TaxMode.custom, taxPercentage: 15, isTaxInclusive: true,
    );
    final r = report(makeOrder('qty-discount', [line], 103.5));
    expect(r.totalTaxCollected, closeTo(13.5, 0.000001));
    expect(r.netSalesRevenue, closeTo(90, 0.000001));
  });

  test('one-cent inclusive VAT never produces negative or tax above gross', () {
    final line = CartItem(
      productId: 'cent', productName: 'Cent', quantity: 1,
      price: 0.01, total: 0.01,
      taxMode: TaxMode.custom, taxPercentage: 15, isTaxInclusive: true,
    );
    final r = report(makeOrder('cent', [line], 0.01));
    expect(r.totalTaxCollected, greaterThanOrEqualTo(0));
    expect(r.totalTaxCollected, lessThan(0.01));
    expect(r.netSalesRevenue + r.totalTaxCollected, closeTo(0.01, 1e-12));
  });

  test('100 percent discount results in zero VAT and zero net sales', () {
    final line = CartItem(
      productId: 'free', productName: 'Free', quantity: 1,
      price: 115, total: 115, discountAmount: 115,
      taxMode: TaxMode.custom, taxPercentage: 15, isTaxInclusive: true,
    );
    final r = report(makeOrder('free', [line], 0));
    expect(r.totalTaxCollected, 0);
    expect(r.netSalesRevenue, 0);
  });
}

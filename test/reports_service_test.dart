import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  AppOrder order({
    required String id,
    required DateTime createdAt,
    required double total,
    String paymentMethod = 'cash',
    bool isCredit = false,
    double paidAmount = 0,
    double? splitCashAmount,
    double? splitNetworkAmount,
    double? costPrice = 10,
  }) {
    return AppOrder(
      id: id,
      merchantId: 'merchant-1',
      branchId: 'branch-2',
      customerId: 'customer-1',
      customerName: 'Customer',
      items: [
        CartItem(
          productId: 'product-1',
          productName: 'Product',
          quantity: 1,
          price: total,
          total: total,
          costPrice: costPrice,
        ),
      ],
      total: total,
      paymentMethod: paymentMethod,
      isCredit: isCredit,
      paidAmount: paidAmount,
      splitCashAmount: splitCashAmount,
      splitNetworkAmount: splitNetworkAmount,
      createdAt: createdAt,
    );
  }

  test('date filter includes exact start and end boundaries', () {
    final start = DateTime(2026, 8, 8, 0, 0, 0);
    final end = DateTime(2026, 8, 8, 23, 59, 59);
    final service = ReportsService(
      [
        order(id: 'start', createdAt: start, total: 10),
        order(id: 'end', createdAt: end, total: 20),
        order(id: 'outside', createdAt: DateTime(2026, 8, 9), total: 30),
      ],
      const [], const [], const [], const [],
    );
    final filtered = service.filterByDate(start, end);
    expect(filtered.orders.map((value) => value.id), containsAll(['start', 'end']));
    expect(filtered.orders.map((value) => value.id), isNot(contains('outside')));
  });

  test('split payment is reported as actual cash and card portions', () {
    final service = ReportsService(
      [order(id: 'split', createdAt: DateTime(2026, 8, 8, 12), total: 100, paymentMethod: 'split', splitCashAmount: 35, splitNetworkAmount: 65)],
      const [], const [], const [], const [],
    );
    expect(service.paymentMethodsBreakdown['cash'], 35);
    expect(service.paymentMethodsBreakdown['card'], 65);
    expect(service.paymentMethodsBreakdown.containsKey('split'), isFalse);
  });

  test('credit order reports only the amount actually received upfront', () {
    final service = ReportsService(
      [order(id: 'credit', createdAt: DateTime(2026, 8, 8, 12), total: 100, paymentMethod: 'cash', isCredit: true, paidAmount: 25)],
      const [], const [], const [], const [],
    );
    expect(service.paymentMethodsBreakdown['cash'], 25);
  });

  test('total debt is outstanding receivable created by orders in report scope', () {
    final service = ReportsService(
      [
        order(id: 'credit-partial', createdAt: DateTime(2026, 8, 8, 12), total: 100, isCredit: true, paidAmount: 30),
        order(id: 'cash-sale', createdAt: DateTime(2026, 8, 8, 13), total: 50, isCredit: false, paidAmount: 50),
      ],
      const [], const [], const [], const [],
    );
    expect(service.totalDebt, 70);
  });

  test('protected historical snapshot overrides legacy item cost', () {
    final service = ReportsService(
      [order(id: 'sale-1', createdAt: DateTime(2026, 8, 8), total: 100, costPrice: 10)],
      const [], const [], const [], const [],
      protectedOrderCosts: const {'sale-1': 27.5},
      canViewCost: true,
    );
    expect(service.totalCOGS, 27.5);
    expect(service.isCOGSComplete, isTrue);
  });

  test('missing protected and legacy cost marks COGS incomplete', () {
    final service = ReportsService(
      [order(id: 'sale-2', createdAt: DateTime(2026, 8, 8), total: 100, costPrice: null)],
      const [], const [], const [], const [],
      canViewCost: true,
    );
    expect(service.totalCOGS, 0);
    expect(service.isCOGSComplete, isFalse);
  });

  test('cost metrics are unavailable without view-cost permission', () {
    final service = ReportsService(
      [order(id: 'sale-3', createdAt: DateTime(2026, 8, 8), total: 100, costPrice: 10)],
      const [], const [], const [], const [],
      protectedOrderCosts: const {'sale-3': 10},
      canViewCost: false,
    );
    expect(service.totalCOGS, 0);
    expect(service.isCOGSComplete, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/order_return.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  CartItem saleLine({
    required int quantity,
    required double total,
  }) =>
      CartItem(
        lineId: 'line-1',
        productId: 'p1',
        productName: 'Product',
        quantity: quantity,
        price: total / quantity,
        total: total,
        taxPercentage: 15,
        isTaxInclusive: true,
      );

  AppOrder sale({
    String id = 'sale-1',
    double total = 115,
    bool credit = false,
    double paid = 115,
    DateTime? createdAt,
  }) =>
      AppOrder(
        id: id,
        merchantId: 'm1',
        branchId: 'main',
        customerId: credit ? 'c1' : 'walk_in',
        customerName: credit ? 'Customer' : 'Walk in',
        items: [saleLine(quantity: 2, total: total)],
        total: total,
        paymentMethod: 'cash',
        isCredit: credit,
        paidAmount: paid,
        createdAt: createdAt ?? DateTime(2026, 8, 10, 12),
      );

  OrderReturn halfReturn({
    String id = 'return-1',
    String originalOrderId = 'sale-1',
    double returnedTotal = 57.5,
    double returnedTax = 7.5,
    DateTime? createdAt,
  }) =>
      OrderReturn(
        id: id,
        merchantId: 'm1',
        branchId: 'main',
        originalOrderId: originalOrderId,
        returnedItems: [saleLine(quantity: 1, total: returnedTotal)],
        returnedTotal: returnedTotal,
        returnedTax: returnedTax,
        paymentMethod: 'cash',
        createdAt: createdAt ?? DateTime(2026, 8, 11, 12),
      );

  test('partial return reconciles revenue VAT COGS and profit exactly', () {
    final service = ReportsService(
      [sale()],
      const [],
      const [],
      const [],
      const [],
      returns: [halfReturn()],
      protectedOrderCosts: const {'sale-1': 60},
      protectedReturnCosts: const {'return-1': 30},
      canViewCost: true,
    );

    expect(service.grossRevenue, closeTo(115, 0.000001));
    expect(service.totalReturns, closeTo(57.5, 0.000001));
    expect(service.totalRevenue, closeTo(57.5, 0.000001));
    expect(service.grossTaxCollected, closeTo(15, 0.000001));
    expect(service.returnedTax, closeTo(7.5, 0.000001));
    expect(service.totalTaxCollected, closeTo(7.5, 0.000001));
    expect(service.netSalesRevenue, closeTo(50, 0.000001));
    expect(service.grossCOGS, closeTo(60, 0.000001));
    expect(service.returnedCOGS, closeTo(30, 0.000001));
    expect(service.totalCOGS, closeTo(30, 0.000001));
    expect(service.netProfit, closeTo(20, 0.000001));
    expect(service.isCOGSComplete, isTrue);
  });

  test('return is recognized on return date without rewriting sale date', () {
    final service = ReportsService(
      [sale()],
      const [],
      const [],
      const [],
      const [],
      returns: [halfReturn()],
      protectedOrderCosts: const {'sale-1': 60},
      protectedReturnCosts: const {'return-1': 30},
      canViewCost: true,
    );

    final daily = service.getDailySales();
    expect(daily.length, 2);
    expect(daily[0].date, DateTime(2026, 8, 10));
    expect(daily[0].amount, closeTo(115, 0.000001));
    expect(daily[1].date, DateTime(2026, 8, 11));
    expect(daily[1].amount, closeTo(-57.5, 0.000001));

    final returnDay = service.filterByDate(
      DateTime(2026, 8, 11),
      DateTime(2026, 8, 11, 23, 59, 59),
    );
    expect(returnDay.grossRevenue, 0);
    expect(returnDay.totalRevenue, closeTo(-57.5, 0.000001));
    expect(returnDay.totalTaxCollected, closeTo(-7.5, 0.000001));
    expect(returnDay.totalCOGS, closeTo(-30, 0.000001));
    expect(returnDay.netProfit, closeTo(-20, 0.000001));
  });

  test('missing protected return cost marks COGS and profit source incomplete', () {
    final service = ReportsService(
      [sale()],
      const [],
      const [],
      const [],
      const [],
      returns: [halfReturn()],
      protectedOrderCosts: const {'sale-1': 60},
      canViewCost: true,
    );
    expect(service.isCOGSComplete, isFalse);
  });

  test('credit receivable subtracts returns even when return is after sale period', () {
    final creditSale = sale(
      id: 'credit-1',
      total: 100,
      credit: true,
      paid: 0,
      createdAt: DateTime(2026, 8, 10, 12),
    );
    final laterReturn = halfReturn(
      id: 'credit-return',
      originalOrderId: 'credit-1',
      returnedTotal: 40,
      returnedTax: 0,
      createdAt: DateTime(2026, 8, 12, 12),
    );
    final base = ReportsService(
      [creditSale],
      const [],
      const [],
      const [],
      const [],
      returns: [laterReturn],
      canViewCost: false,
    );
    final saleDay = base.filterByDate(
      DateTime(2026, 8, 10),
      DateTime(2026, 8, 10, 23, 59, 59),
    );
    expect(saleDay.totalDebt, closeTo(60, 0.000001));
  });
}

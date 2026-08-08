import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/expenses/domain/expense.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  AppOrder sale({
    required String id,
    required double total,
    required DateTime createdAt,
    required List<CartItem> items,
    String paymentMethod = 'cash',
    bool isCredit = false,
    double paidAmount = 0,
    double? splitCashAmount,
    double? splitNetworkAmount,
  }) {
    return AppOrder(
      id: id,
      merchantId: 'merchant-1',
      branchId: 'branch-a',
      customerId: 'customer-1',
      customerName: 'Customer',
      items: items,
      total: total,
      paymentMethod: paymentMethod,
      isCredit: isCredit,
      paidAmount: paidAmount,
      splitCashAmount: splitCashAmount,
      splitNetworkAmount: splitNetworkAmount,
      createdAt: createdAt,
    );
  }

  CartItem item({
    required String id,
    required double total,
    required int quantity,
    bool inclusive = true,
    double vat = 15,
  }) {
    return CartItem(
      productId: id,
      productName: id,
      quantity: quantity,
      price: total / quantity,
      total: total,
      isTaxInclusive: inclusive,
      taxPercentage: vat,
    );
  }

  Expense expense(double amount) {
    return Expense(
      id: 'expense-1',
      merchantId: 'merchant-1',
      branchId: 'branch-a',
      title: 'Rent',
      amount: amount,
      date: DateTime(2026, 8, 8),
      createdAt: DateTime(2026, 8, 8),
    );
  }

  double inclusiveVat(double gross, double rate) {
    final divisor = 1 + (rate / 100);
    return gross - (gross / divisor);
  }

  test('deterministic reference model reconciles VAT, payments and profit', () {
    final orders = [
      sale(
        id: 'cash-inclusive',
        total: 115,
        createdAt: DateTime(2026, 8, 8, 10),
        items: [item(id: 'p1', total: 115, quantity: 1)],
        paymentMethod: 'cash',
        paidAmount: 115,
      ),
      sale(
        id: 'split-inclusive',
        total: 230,
        createdAt: DateTime(2026, 8, 8, 11),
        items: [item(id: 'p2', total: 230, quantity: 2)],
        paymentMethod: 'split',
        paidAmount: 230,
        splitCashAmount: 80,
        splitNetworkAmount: 150,
      ),
      sale(
        id: 'credit-inclusive',
        total: 115,
        createdAt: DateTime(2026, 8, 8, 12),
        items: [item(id: 'p3', total: 115, quantity: 1)],
        paymentMethod: 'cash',
        isCredit: true,
        paidAmount: 15,
      ),
    ];

    final service = ReportsService(
      orders,
      const [],
      [expense(50)],
      const [],
      const [],
      protectedOrderCosts: const {
        'cash-inclusive': 60,
        'split-inclusive': 120,
        'credit-inclusive': 55,
      },
      canViewCost: true,
      defaultTaxPercentage: 15,
      defaultIsTaxInclusive: true,
    );

    final expectedGrossSales = 460.0;
    final expectedVat =
        inclusiveVat(115, 15) + inclusiveVat(230, 15) + inclusiveVat(115, 15);
    final expectedNetSales = expectedGrossSales - expectedVat;
    final expectedCash = 115 + 80 + 15;
    final expectedCard = 150.0;
    final expectedDebt = 100.0;
    final expectedCogs = 60 + 120 + 55.0;
    final expectedExpenses = 50.0;
    final expectedNetProfit =
        expectedGrossSales - expectedVat - expectedCogs - expectedExpenses;

    expect(service.totalRevenue, expectedGrossSales);
    expect(service.totalTaxCollected, closeTo(expectedVat, 0.000001));
    expect(service.netSalesRevenue, closeTo(expectedNetSales, 0.000001));
    expect(service.paymentMethodsBreakdown['cash'], expectedCash);
    expect(service.paymentMethodsBreakdown['card'], expectedCard);
    expect(service.totalDebt, expectedDebt);
    expect(service.totalCOGS, expectedCogs);
    expect(service.totalExpenses, expectedExpenses);
    expect(service.netProfit, closeTo(expectedNetProfit, 0.000001));
    expect(service.isCOGSComplete, isTrue);
  });
}

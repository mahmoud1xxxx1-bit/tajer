import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/customers/domain/customer_debt_payment.dart';
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

  test('seeded accounting matrix reconciles branches and consolidated totals',
      () {
    final random = Random(108);
    final branches = ['branch-a', 'branch-b'];
    final orders = <AppOrder>[];
    final expenses = <Expense>[];
    final debtPayments = <CustomerDebtPayment>[];
    final protectedCosts = <String, double>{};

    for (var i = 0; i < 80; i++) {
      final branchId = branches[i % branches.length];
      final paymentMethod =
          ['cash', 'card', 'transfer', 'split'][random.nextInt(4)];
      final quantity = 1 + random.nextInt(4);
      final unitGross = [23.0, 46.0, 57.5, 115.0][random.nextInt(4)];
      final total = unitGross * quantity;
      final isCredit = random.nextInt(5) == 0;
      final isCancelled = random.nextInt(11) == 0;
      final paidAmount = isCredit ? total * 0.25 : total;
      final splitCash = paymentMethod == 'split' ? total * 0.4 : null;
      final splitCard = paymentMethod == 'split' ? total * 0.6 : null;
      final orderId = 'order-$i';

      orders.add(
        AppOrder(
          id: orderId,
          merchantId: 'merchant-1',
          branchId: branchId,
          customerId: isCredit ? 'customer-${i % 7}' : 'walk_in',
          customerName: 'Customer',
          status: isCancelled ? 'cancelled' : 'pending',
          items: [
            CartItem(
              productId: 'product-${i % 9}',
              productName: 'Product',
              quantity: quantity,
              price: unitGross,
              total: total,
              taxPercentage: i.isEven ? 15 : 5,
              isTaxInclusive: i % 3 != 0,
            ),
          ],
          total: total,
          paymentMethod: paymentMethod,
          isCredit: isCredit,
          paidAmount: paidAmount,
          splitCashAmount: splitCash,
          splitNetworkAmount: splitCard,
          createdAt: DateTime(2026, 8, 8, i % 24, i % 60),
        ),
      );
      protectedCosts[orderId] = quantity * (8 + (i % 5));

      if (isCredit && !isCancelled) {
        debtPayments.add(
          CustomerDebtPayment(
            id: 'debt-pay-$i',
            merchantId: 'merchant-1',
            customerId: 'customer-${i % 7}',
            branchId: branchId,
            amount: total * 0.1,
            paymentMethod: i.isEven ? 'cash' : 'transfer',
            allocations: [
              CustomerDebtAllocation(orderId: orderId, amount: total * 0.1),
            ],
            createdAt: DateTime(2026, 8, 8, i % 24, (i + 5) % 60),
          ),
        );
      }
    }

    for (var i = 0; i < 12; i++) {
      expenses.add(
        Expense(
          id: 'expense-$i',
          merchantId: 'merchant-1',
          branchId: branches[i % branches.length],
          title: 'Expense',
          amount: 10.0 + i,
          isCancelled: i % 7 == 0,
          date: DateTime(2026, 8, 8),
          createdAt: DateTime(2026, 8, 8),
        ),
      );
    }

    ReportsService reportFor(String? branchId) {
      final scopedOrders = branchId == null
          ? orders
          : orders.where((order) => order.branchId == branchId).toList();
      final scopedExpenses = branchId == null
          ? expenses
          : expenses.where((expense) => expense.branchId == branchId).toList();
      final scopedDebtPayments = branchId == null
          ? debtPayments
          : debtPayments
              .where((payment) => payment.branchId == branchId)
              .toList();
      final scopedOrderIds = scopedOrders.map((order) => order.id).toSet();
      return ReportsService(
        scopedOrders,
        const [],
        scopedExpenses,
        const [],
        const [],
        debtPayments: scopedDebtPayments,
        protectedOrderCosts: {
          for (final entry in protectedCosts.entries)
            if (scopedOrderIds.contains(entry.key)) entry.key: entry.value,
        },
        canViewCost: true,
      );
    }

    final consolidated = reportFor(null);
    final branchReports = branches.map(reportFor).toList();

    double sum(double Function(ReportsService service) pick) =>
        branchReports.fold(0.0, (total, service) => total + pick(service));

    expect(sum((service) => service.totalRevenue),
        closeTo(consolidated.totalRevenue, 0.000001));
    expect(sum((service) => service.totalTaxCollected),
        closeTo(consolidated.totalTaxCollected, 0.000001));
    expect(sum((service) => service.totalDebt),
        closeTo(consolidated.totalDebt, 0.000001));
    expect(sum((service) => service.totalCOGS),
        closeTo(consolidated.totalCOGS, 0.000001));
    expect(sum((service) => service.totalExpenses),
        closeTo(consolidated.totalExpenses, 0.000001));
    expect(sum((service) => service.netProfit),
        closeTo(consolidated.netProfit, 0.000001));

    for (final method in ['cash', 'card', 'transfer']) {
      final branchTotal = branchReports.fold<double>(
        0.0,
        (total, service) =>
            total + (service.paymentMethodsBreakdown[method] ?? 0.0),
      );
      expect(
          branchTotal,
          closeTo(
              consolidated.paymentMethodsBreakdown[method] ?? 0.0, 0.000001));
    }
    expect(consolidated.isCOGSComplete, isTrue);
  });
}

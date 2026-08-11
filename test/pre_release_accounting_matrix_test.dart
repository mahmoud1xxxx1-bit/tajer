import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/customers/domain/customer_debt_payment.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/products/domain/product.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  AppOrder order({
    required String id,
    required double total,
    String paymentMethod = 'cash',
    bool isCredit = false,
    double paidAmount = 0,
    String status = 'pending',
    double? splitCash,
    double? splitCard,
    CartItem? item,
  }) {
    return AppOrder(
      id: id,
      merchantId: 'm1',
      branchId: 'main',
      customerId: isCredit ? 'c1' : 'walk_in',
      customerName: 'Customer',
      items: [item ?? CartItem(productId: 'p1', productName: 'P1', quantity: 1, price: total, total: total, taxPercentage: 15, isTaxInclusive: true)],
      total: total,
      paymentMethod: paymentMethod,
      isCredit: isCredit,
      paidAmount: paidAmount,
      status: status,
      splitCashAmount: splitCash,
      splitNetworkAmount: splitCard,
      createdAt: DateTime(2026, 8, 11),
    );
  }

  ReportsService report(List<AppOrder> orders, {List<CustomerDebtPayment> debtPayments = const [], bool canViewCost = true, double defaultTax = 15}) {
    return ReportsService(
      orders,
      const [],
      const [],
      const [],
      const [],
      debtPayments: debtPayments,
      protectedOrderCosts: {for (final o in orders) if (o.status != 'cancelled' && o.status != 'debt_repayment') o.id: o.total * 0.4},
      canViewCost: canViewCost,
      defaultTaxPercentage: defaultTax,
      defaultIsTaxInclusive: true,
    );
  }

  test('cash/card/transfer/split actual money-in reconcile exactly', () {
    final r = report([
      order(id: 'cash', total: 100, paymentMethod: 'cash', paidAmount: 100),
      order(id: 'card', total: 200, paymentMethod: 'card', paidAmount: 200),
      order(id: 'transfer', total: 300, paymentMethod: 'transfer', paidAmount: 300),
      order(id: 'split', total: 400, paymentMethod: 'split', paidAmount: 400, splitCash: 150, splitCard: 250),
    ]);
    expect(r.totalRevenue, 1000);
    expect(r.paymentMethodsBreakdown['cash'], 250);
    expect(r.paymentMethodsBreakdown['card'], 450);
    expect(r.paymentMethodsBreakdown['transfer'], 300);
    expect(r.paymentMethodsBreakdown.values.fold<double>(0, (a, b) => a + b), 1000);
  });

  test('credit sale separates revenue, outstanding debt and later collection', () {
    final credit = order(id: 'credit', total: 500, paymentMethod: 'cash', isCredit: true, paidAmount: 100);
    final payment = CustomerDebtPayment(
      id: 'dp1', merchantId: 'm1', customerId: 'c1', branchId: 'main', amount: 150,
      paymentMethod: 'transfer', allocations: const [CustomerDebtAllocation(orderId: 'credit', amount: 150)],
      createdAt: DateTime(2026, 8, 11, 12),
    );
    final r = report([credit], debtPayments: [payment]);
    expect(r.totalRevenue, 500);
    expect(r.totalDebt, 400);
    expect(r.paymentMethodsBreakdown['cash'], 100);
    expect(r.paymentMethodsBreakdown['transfer'], 150);
  });

  test('cancelled sale contributes zero revenue/tax/COGS/cashflow', () {
    final r = report([order(id: 'cancel', total: 115, paymentMethod: 'cash', paidAmount: 115, status: 'cancelled')]);
    expect(r.totalRevenue, 0);
    expect(r.totalTaxCollected, 0);
    expect(r.totalCOGS, 0);
    expect(r.paymentMethodsBreakdown.values.fold<double>(0, (a, b) => a + b), 0);
  });

  test('legacy debt repayment is cashflow but never sales revenue', () {
    final r = report([order(id: 'legacy-debt', total: 80, paymentMethod: 'cash', paidAmount: 80, status: 'debt_repayment')]);
    expect(r.totalRevenue, 0);
    expect(r.totalTaxCollected, 0);
    expect(r.totalCOGS, 0);
    expect(r.paymentMethodsBreakdown['cash'], 80);
  });

  test('inclusive VAT 15% extracts exactly 15 from gross 115', () {
    final r = report([order(id: 'vat-inc', total: 115, paidAmount: 115)]);
    expect(r.totalTaxCollected, closeTo(15, 0.000001));
    expect(r.netSalesRevenue, closeTo(100, 0.000001));
  });

  test('exclusive VAT 15% on base 100 calculates 15 tax', () {
    final line = CartItem(productId: 'p', productName: 'P', quantity: 1, price: 100, total: 100, taxPercentage: 15, isTaxInclusive: false);
    final r = report([order(id: 'vat-ex', total: 115, paidAmount: 115, item: line)]);
    expect(r.totalTaxCollected, closeTo(15, 0.000001));
  });

  test('tax-exempt line must contribute zero tax even when store default is 15%', () {
    final line = CartItem(productId: 'exempt', productName: 'Exempt', quantity: 1, price: 100, total: 100, taxMode: TaxMode.exempt, taxPercentage: null, isTaxInclusive: true);
    final r = report([order(id: 'tax-exempt', total: 100, paidAmount: 100, item: line)], defaultTax: 15);
    expect(r.totalTaxCollected, 0, reason: 'TaxMode.exempt must override store default tax');
  });

  test('cost privacy is fail-closed at report output', () {
    final r = report([order(id: 'private-cost', total: 100, paidAmount: 100)], canViewCost: false);
    expect(r.totalCOGS, 0);
    expect(r.isCOGSComplete, isFalse);
  });

  test('discounted inclusive line taxes only post-discount taxable amount', () {
    final line = CartItem(productId: 'd', productName: 'D', quantity: 1, price: 115, total: 115, discountAmount: 23, taxPercentage: 15, isTaxInclusive: true);
    final r = report([order(id: 'discount', total: 92, paidAmount: 92, item: line)]);
    expect(r.totalTaxCollected, closeTo(12, 0.000001));
    expect(r.netSalesRevenue, closeTo(80, 0.000001));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/customers/domain/customer_debt_payment.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/reports/data/report_cashflow_ledger.dart';

void main() {
  AppOrder sale({
    required String id,
    required String branchId,
    required double total,
    String paymentMethod = 'cash',
    bool isCredit = false,
    double paidAmount = 0,
    double? splitCashAmount,
    double? splitNetworkAmount,
  }) {
    return AppOrder(
      id: id,
      merchantId: 'merchant-1',
      branchId: branchId,
      customerId: 'walk_in',
      customerName: 'Walk in',
      total: total,
      paymentMethod: paymentMethod,
      isCredit: isCredit,
      paidAmount: paidAmount,
      splitCashAmount: splitCashAmount,
      splitNetworkAmount: splitNetworkAmount,
      createdAt: DateTime(2026, 8, 8, 12),
    );
  }

  CustomerDebtPayment debtPayment({
    required String id,
    required String branchId,
    required double amount,
    required String paymentMethod,
  }) {
    return CustomerDebtPayment(
      id: id,
      merchantId: 'merchant-1',
      customerId: 'customer-1',
      branchId: branchId,
      amount: amount,
      paymentMethod: paymentMethod,
      createdAt: DateTime(2026, 8, 8, 13),
    );
  }

  test('debt collections are included in actual money-in totals', () {
    final totals = ReportCashflowLedger.paymentMethods(
      orders: [
        sale(id: 'sale-1', branchId: 'main', total: 100),
        sale(
          id: 'credit-1',
          branchId: 'main',
          total: 80,
          isCredit: true,
          paidAmount: 20,
        ),
      ],
      debtPayments: [
        debtPayment(
          id: 'payment-1',
          branchId: 'main',
          amount: 30,
          paymentMethod: 'card',
        ),
      ],
    );

    expect(totals['cash'], 120);
    expect(totals['card'], 30);
  });

  test('branch cashflow includes only collections received by that branch', () {
    final totals = ReportCashflowLedger.paymentMethods(
      orders: [
        sale(id: 'main-sale', branchId: 'main', total: 50),
        sale(id: 'b2-sale', branchId: 'branch-2', total: 70),
      ],
      debtPayments: [
        debtPayment(
          id: 'main-debt',
          branchId: 'main',
          amount: 15,
          paymentMethod: 'transfer',
        ),
        debtPayment(
          id: 'b2-debt',
          branchId: 'branch-2',
          amount: 25,
          paymentMethod: 'transfer',
        ),
      ],
      branchId: 'branch-2',
    );

    expect(totals['cash'], 70);
    expect(totals['transfer'], 25);
  });

  test('split sale remains separated into cash and card', () {
    final totals = ReportCashflowLedger.paymentMethods(
      orders: [
        sale(
          id: 'split',
          branchId: 'main',
          total: 100,
          paymentMethod: 'split',
          splitCashAmount: 40,
          splitNetworkAmount: 60,
        ),
      ],
      debtPayments: const [],
    );

    expect(totals['cash'], 40);
    expect(totals['card'], 60);
    expect(totals.containsKey('split'), isFalse);
  });
}

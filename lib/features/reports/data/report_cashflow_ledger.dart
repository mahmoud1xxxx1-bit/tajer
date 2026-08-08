import '../../customers/domain/customer_debt_payment.dart';
import '../../orders/domain/order.dart';

/// Produces actual money-in totals by payment method for reports.
///
/// Sales revenue and cash collections are intentionally different concepts:
/// credit sales belong to revenue when invoiced, while later debt collections
/// belong to cashflow when the money is actually received. This ledger keeps
/// those two concepts separate and attributes debt collections to the branch
/// that received them.
class ReportCashflowLedger {
  const ReportCashflowLedger._();

  static Map<String, double> paymentMethods({
    required List<AppOrder> orders,
    required List<CustomerDebtPayment> debtPayments,
    String? branchId,
  }) {
    final result = <String, double>{};

    void add(String method, double amount) {
      if (amount <= 0) return;
      result[method] = (result[method] ?? 0.0) + amount;
    }

    for (final order in orders) {
      if (order.status == 'cancelled') continue;
      if (branchId != null && order.branchId != branchId) continue;

      final method = order.paymentMethod ?? 'cash';
      if (method == 'split' ||
          order.splitCashAmount != null ||
          order.splitNetworkAmount != null) {
        add('cash', order.splitCashAmount ?? 0.0);
        add('card', order.splitNetworkAmount ?? 0.0);
        continue;
      }

      // Regular sale: the whole total was received.
      // Credit sale: only the upfront paid amount was received at sale time.
      final received = order.isCredit ? order.paidAmount : order.total;
      add(method, received);
    }

    for (final payment in debtPayments) {
      if (branchId != null && payment.branchId != branchId) continue;
      add(payment.paymentMethod, payment.amount);
    }

    return result;
  }
}

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

  /// Tajer historically used more than one persisted name for non-cash payment
  /// methods. Reports must group equivalent methods under one stable key so a
  /// Mada sale cannot silently disappear into a separate/unlabelled bucket.
  static String normalizePaymentMethod(String? raw) {
    switch ((raw ?? 'cash').trim().toLowerCase()) {
      case 'cash':
        return 'cash';
      case 'mada':
      case 'card':
      case 'network':
      case 'apple_pay':
      case 'applepay':
        return 'card';
      case 'transfer':
      case 'bank_transfer':
      case 'bank transfer':
        return 'transfer';
      default:
        return (raw == null || raw.trim().isEmpty)
            ? 'cash'
            : raw.trim().toLowerCase();
    }
  }

  static Map<String, double> paymentMethods({
    required List<AppOrder> orders,
    required List<CustomerDebtPayment> debtPayments,
    String? branchId,
  }) {
    final result = <String, double>{};

    void add(String? method, double amount) {
      if (amount <= 0) return;
      final normalized = normalizePaymentMethod(method);
      result[normalized] = (result[normalized] ?? 0.0) + amount;
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

      // Legacy v107 debt repayments were sometimes represented as synthetic
      // orders. New multi-branch collections use immutable debt-payment records.
      if (order.status == 'debt_repayment') {
        add(method, order.paidAmount);
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

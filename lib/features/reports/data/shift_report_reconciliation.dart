import '../../shifts/domain/shift.dart';

/// Result of comparing report cash-in totals against the operational shift
/// counters for the same branch and time window.
class ShiftReportReconciliation {
  final double expectedCashIn;
  final double reportedCashIn;
  final double expectedCardIn;
  final double reportedCardIn;
  final double expectedTransferIn;
  final double reportedTransferIn;

  const ShiftReportReconciliation({
    required this.expectedCashIn,
    required this.reportedCashIn,
    required this.expectedCardIn,
    required this.reportedCardIn,
    required this.expectedTransferIn,
    required this.reportedTransferIn,
  });

  double get cashDifference => reportedCashIn - expectedCashIn;
  double get cardDifference => reportedCardIn - expectedCardIn;
  double get transferDifference => reportedTransferIn - expectedTransferIn;

  bool isBalanced({double tolerance = 0.01}) =>
      cashDifference.abs() <= tolerance &&
      cardDifference.abs() <= tolerance &&
      transferDifference.abs() <= tolerance;
}

/// Reconciles the report cashflow ledger with a Shift snapshot.
///
/// Important accounting boundary:
/// - This compares GROSS MONEY IN only.
/// - Drawer expenses and refunds are intentionally not included here because
///   they are cash-out movements and belong to drawer reconciliation, not the
///   report's payment-method inflow breakdown.
/// - Debt collections are included because they are real money received during
///   the shift even though they are not new sales revenue.
class ShiftReportReconciler {
  const ShiftReportReconciler._();

  static ShiftReportReconciliation reconcile({
    required Shift shift,
    required Map<String, double> reportedPaymentMethods,
  }) {
    double value(String key) => reportedPaymentMethods[key] ?? 0.0;

    // Accept both historical/common aliases without double counting. New
    // reporting code should prefer `card` and `transfer`.
    final reportedCard = value('card') + value('network');
    final reportedTransfer = value('transfer') + value('bank_transfer');

    return ShiftReportReconciliation(
      expectedCashIn:
          (shift.cashSales ?? 0.0) + (shift.debtCollectionsCash ?? 0.0),
      reportedCashIn: value('cash'),
      expectedCardIn:
          (shift.cardTotal ?? 0.0) + (shift.debtCollectionsCard ?? 0.0),
      reportedCardIn: reportedCard,
      expectedTransferIn:
          (shift.transferTotal ?? 0.0) +
          (shift.debtCollectionsTransfer ?? 0.0),
      reportedTransferIn: reportedTransfer,
    );
  }
}

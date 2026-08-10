import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/reports/data/shift_report_reconciliation.dart';
import 'package:tajer/features/shifts/domain/shift.dart';

void main() {
  Shift shift({
    double cashSales = 0,
    double cardTotal = 0,
    double transferTotal = 0,
    double debtCash = 0,
    double debtCard = 0,
    double debtTransfer = 0,
  }) {
    return Shift(
      id: 'shift-1',
      merchantId: 'merchant-1',
      branchId: 'branch-1',
      employeeId: 'employee-1',
      employeeName: 'Employee',
      startTime: DateTime(2026, 8, 8, 10),
      startCash: 100,
      cashSales: cashSales,
      cardTotal: cardTotal,
      transferTotal: transferTotal,
      debtCollectionsCash: debtCash,
      debtCollectionsCard: debtCard,
      debtCollectionsTransfer: debtTransfer,
      status: 'open',
    );
  }

  test('balances gross money-in including debt collections', () {
    final result = ShiftReportReconciler.reconcile(
      shift: shift(
        cashSales: 120,
        cardTotal: 200,
        transferTotal: 80,
        debtCash: 30,
        debtCard: 25,
        debtTransfer: 15,
      ),
      reportedPaymentMethods: const {
        'cash': 150,
        'card': 225,
        'transfer': 95,
      },
    );

    expect(result.isBalanced(), isTrue);
    expect(result.cashDifference, 0);
    expect(result.cardDifference, 0);
    expect(result.transferDifference, 0);
  });

  test('detects a missing debt collection in branch report', () {
    final result = ShiftReportReconciler.reconcile(
      shift: shift(cashSales: 100, debtCash: 40),
      reportedPaymentMethods: const {'cash': 100},
    );

    expect(result.isBalanced(), isFalse);
    expect(result.cashDifference, -40);
  });

  test('normalizes card and transfer aliases used by legacy data', () {
    final result = ShiftReportReconciler.reconcile(
      shift: shift(cardTotal: 50, transferTotal: 70),
      reportedPaymentMethods: const {
        'network': 50,
        'bank_transfer': 70,
      },
    );

    expect(result.isBalanced(), isTrue);
  });

  test('small floating point differences stay within accounting tolerance', () {
    final result = ShiftReportReconciler.reconcile(
      shift: shift(cashSales: 100),
      reportedPaymentMethods: const {'cash': 100.005},
    );

    expect(result.isBalanced(), isTrue);
    expect(result.isBalanced(tolerance: 0.001), isFalse);
  });

  test('shift archive and details expose branch and full payment breakdown',
      () {
    final details =
        File('lib/features/shifts/presentation/shift_details_screen.dart')
            .readAsStringSync();
    final archive =
        File('lib/features/shifts/presentation/shifts_archive_screen.dart')
            .readAsStringSync();

    expect(details, contains("branchName"));
    expect(details, contains("displayBranchName"));
    expect(
        details,
        isNot(contains(
            "_buildRow(isAr ? 'Ø§Ù„ÙØ±Ø¹:' : 'Branch:', shift.branchId)")));
    expect(archive, contains("globalDisplayResolverProvider"));
    expect(archive, contains("resolveBranchName"));
    expect(details, contains("shift.debtCollectionsCard ?? 0.0"));
    expect(details, contains("shift.refundsCard ?? 0.0"));
    expect(details, contains("shift.debtCollectionsTransfer ?? 0.0"));
    expect(details, contains("shift.refundsTransfer ?? 0.0"));
  });
}

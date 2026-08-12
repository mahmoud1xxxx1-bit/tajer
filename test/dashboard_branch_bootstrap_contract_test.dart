import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/branches/domain/branch.dart';
import 'package:tajer/features/branches/presentation/branch_context.dart';

void main() {
  test('dashboard waits for app user and branch context before protected reads',
      () {
    final source =
        File('lib/features/dashboard/presentation/dashboard_screen.dart')
            .readAsStringSync();

    expect(source, contains('appUserState.isLoading'));
    expect(source, contains('branchContext.isReady'));
    expect(source, contains('CircularProgressIndicator'));
  });

  test('app user stream waits for restored auth session before user reads', () {
    final source = File('lib/features/authentication/data/auth_repository.dart')
        .readAsStringSync();

    expect(source, contains('authStateChanges()'));
    expect(source, contains('.asyncExpand((user)'));
    expect(
        source, isNot(contains('ref.watch(authStateChangesProvider).value')));
  });

  test('employee branch selection is clamped before protected reads', () {
    for (var i = 0; i < 20; i++) {
      final savedBranch = i.isEven ? BranchIds.main : 'branch-3';
      expect(
          resolveAllowedBranchId(savedBranch, const ['branch-2']), 'branch-2');
      expect(
          resolveAllowedBranchId('branch-2', const ['branch-2']), 'branch-2');
    }

    expect(effectiveEmployeeBranchIds(const []), const <String>[]);
    expect(effectiveEmployeeBranchIds(const ['branch-2', 'branch-2']),
        const ['branch-2']);
  });

  test('dashboard sales cards use daily metrics that exclude non-sales records',
      () {
    final dashboardSource =
        File('lib/features/dashboard/presentation/dashboard_screen.dart')
            .readAsStringSync();
    final metricsSource =
        File('lib/features/dashboard/domain/dashboard_daily_metrics.dart')
            .readAsStringSync();

    expect(dashboardSource, contains('DashboardDailyMetrics.fromOrders(orders)'));
    expect(dashboardSource, contains('dailyMetrics.totalSales'));
    expect(dashboardSource, contains('dailyMetrics.ordersCount'));

    expect(metricsSource, contains("order.status == 'cancelled'"));
    expect(metricsSource, contains("order.status == 'debt_repayment'"));
    expect(metricsSource, contains('return false;'));
    expect(metricsSource, contains('final start = DateTime('));
    expect(metricsSource, contains('createdAt.isBefore(end)'));
  });
}

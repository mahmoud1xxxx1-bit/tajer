import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/dashboard/presentation/dashboard_daily_summary.dart';
import 'package:tajer/features/orders/domain/order.dart';

AppOrder makeOrder({
  required String id,
  required double total,
  required DateTime createdAt,
  String status = 'completed',
}) {
  return AppOrder(
    id: id,
    merchantId: 'm1',
    branchId: 'main',
    customerId: '',
    customerName: '',
    total: total,
    status: status,
    createdAt: createdAt,
  );
}

void main() {
  test('dashboard totals include only live orders from the local calendar day',
      () {
    final now = DateTime(2026, 8, 12, 14, 30);

    final summary = DashboardDailySummary.fromOrders(
      [
        makeOrder(
          id: 'today-1',
          total: 100,
          createdAt: DateTime(2026, 8, 12, 0, 0),
        ),
        makeOrder(
          id: 'today-2',
          total: 50,
          createdAt: DateTime(2026, 8, 12, 23, 59, 59),
        ),
        makeOrder(
          id: 'yesterday',
          total: 999,
          createdAt: DateTime(2026, 8, 11, 23, 59, 59),
        ),
        makeOrder(
          id: 'tomorrow',
          total: 999,
          createdAt: DateTime(2026, 8, 13, 0, 0),
        ),
        makeOrder(
          id: 'cancelled',
          total: 400,
          createdAt: DateTime(2026, 8, 12, 12),
          status: 'cancelled',
        ),
        makeOrder(
          id: 'debt-repayment',
          total: 300,
          createdAt: DateTime(2026, 8, 12, 13),
          status: 'debt_repayment',
        ),
      ],
      now: now,
    );

    expect(summary.totalSales, 150);
    expect(summary.ordersCount, 2);
  });

  test('dashboard reads orders from the active branch-scoped provider', () {
    final source = File(
      'lib/features/dashboard/presentation/dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('ref.watch(branchOrdersStreamProvider)'));
    expect(source, isNot(contains('ref.watch(ordersStreamProvider)')));
  });
}

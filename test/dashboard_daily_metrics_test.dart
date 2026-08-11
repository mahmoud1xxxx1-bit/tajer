import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/dashboard/domain/dashboard_daily_metrics.dart';
import 'package:tajer/features/orders/domain/order.dart';

AppOrder order({
  required String id,
  required double total,
  required DateTime createdAt,
  String status = 'completed',
}) {
  return AppOrder(
    id: id,
    merchantId: 'merchant-1',
    branchId: 'main',
    customerId: 'walk-in',
    customerName: 'Walk-in',
    total: total,
    status: status,
    paidAmount: total,
    createdAt: createdAt,
  );
}

void main() {
  test('dashboard counts only the local calendar day', () {
    final now = DateTime(2026, 8, 12, 14, 30);
    final metrics = DashboardDailyMetrics.fromOrders([
      order(
        id: 'yesterday',
        total: 900,
        createdAt: DateTime(2026, 8, 11, 23, 59, 59),
      ),
      order(id: 'start', total: 60, createdAt: DateTime(2026, 8, 12, 0, 0)),
      order(
        id: 'today',
        total: 40,
        createdAt: DateTime(2026, 8, 12, 23, 59, 59),
      ),
      order(id: 'tomorrow', total: 700, createdAt: DateTime(2026, 8, 13, 0, 0)),
    ], now: now);

    expect(metrics.ordersCount, 2);
    expect(metrics.totalSales, 100);
  });

  test('dashboard excludes cancelled and debt repayment records', () {
    final now = DateTime(2026, 8, 12, 12);
    final metrics = DashboardDailyMetrics.fromOrders([
      order(id: 'sale', total: 100, createdAt: DateTime(2026, 8, 12, 9)),
      order(
        id: 'cancelled',
        total: 200,
        createdAt: DateTime(2026, 8, 12, 10),
        status: 'cancelled',
      ),
      order(
        id: 'debt',
        total: 300,
        createdAt: DateTime(2026, 8, 12, 11),
        status: 'debt_repayment',
      ),
    ], now: now);

    expect(metrics.ordersCount, 1);
    expect(metrics.totalSales, 100);
  });
}

import '../../orders/domain/order.dart';

class DashboardDailySummary {
  final double totalSales;
  final int ordersCount;

  const DashboardDailySummary({
    required this.totalSales,
    required this.ordersCount,
  });

  factory DashboardDailySummary.fromOrders(
    List<AppOrder> orders, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final startOfDay = DateTime(current.year, current.month, current.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    final todayOrders = orders.where((order) {
      final isLive =
          order.status != 'cancelled' && order.status != 'debt_repayment';
      final isToday = !order.createdAt.isBefore(startOfDay) &&
          order.createdAt.isBefore(startOfNextDay);
      return isLive && isToday;
    }).toList();

    return DashboardDailySummary(
      totalSales:
          todayOrders.fold<double>(0, (sum, order) => sum + order.total),
      ordersCount: todayOrders.length,
    );
  }
}

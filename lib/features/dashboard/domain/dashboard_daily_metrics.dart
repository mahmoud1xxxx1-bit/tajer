import '../../orders/domain/order.dart';

class DashboardDailyMetrics {
  final double totalSales;
  final int ordersCount;

  const DashboardDailyMetrics({
    required this.totalSales,
    required this.ordersCount,
  });

  factory DashboardDailyMetrics.fromOrders(
    List<AppOrder> orders, {
    DateTime? now,
  }) {
    final localNow = (now ?? DateTime.now()).toLocal();
    final start = DateTime(localNow.year, localNow.month, localNow.day);
    final end = start.add(const Duration(days: 1));

    final todayOrders = orders.where((order) {
      if (order.status == 'cancelled' || order.status == 'debt_repayment') {
        return false;
      }
      final createdAt = order.createdAt.toLocal();
      return !createdAt.isBefore(start) && createdAt.isBefore(end);
    }).toList(growable: false);

    return DashboardDailyMetrics(
      totalSales: todayOrders.fold<double>(
        0.0,
        (sum, order) => sum + order.total,
      ),
      ordersCount: todayOrders.length,
    );
  }
}

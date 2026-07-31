import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../orders/data/order_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/theme/glass_card.dart';

class AnalyticsDashboardWidget extends ConsumerWidget {
  const AnalyticsDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    if (ordersAsync.isLoading || expensesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = ordersAsync.value ?? [];
    final expenses = expensesAsync.value ?? [];

    // Process data for charts
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // Line Chart Data: Sales per day for last 7 days
    Map<String, double> salesByDay = {};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      salesByDay[DateFormat('yyyy-MM-dd').format(date)] = 0;
    }

    for (var order in orders) {
      if (order.createdAt.isAfter(sevenDaysAgo)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(order.createdAt);
        if (salesByDay.containsKey(dateStr)) {
          salesByDay[dateStr] = salesByDay[dateStr]! + order.paidAmount;
        }
      }
    }

    List<FlSpot> salesSpots = [];
    int index = 0;
    salesByDay.forEach((date, amount) {
      salesSpots.add(FlSpot(index.toDouble(), amount));
      index++;
    });

    // Pie Chart Data: Expense Categories
    Map<String, double> expensesByCategory = {};
    for (var expense in expenses) {
      if (expense.date.isAfter(sevenDaysAgo)) {
        expensesByCategory[expense.category] = (expensesByCategory[expense.category] ?? 0) + expense.amount;
      }
    }

    List<PieChartSectionData> expenseSections = [];
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    int colorIndex = 0;
    expensesByCategory.forEach((category, amount) {
      expenseSections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: amount,
          title: '$category\n${amount.toStringAsFixed(0)}',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Tajawal'),
        )
      );
      colorIndex++;
    });

    final appUser = ref.watch(appUserProvider).value;
    final isPremium = appUser?.plan == 'premium' || appUser?.plan == 'admin' || appUser?.email == 'love.dotk@gmail.com';

    final chartsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مبيعات آخر 7 أيام', style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < salesByDay.keys.length) {
                              final dateStr = salesByDay.keys.elementAt(value.toInt());
                              final date = DateTime.parse(dateStr);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('E', 'ar').format(date), style: const TextStyle(fontSize: 10, fontFamily: 'Tajawal')),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: salesSpots,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (expenseSections.isNotEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('توزيع مصروفات آخر 7 أيام', style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: expenseSections,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (isPremium) {
      return chartsWidget;
    }

    // Paywall overlay for free users
    return Stack(
      children: [
        chartsWidget,
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, color: Colors.amber, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'التحليلات المتقدمة مقفلة',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                        onPressed: () {
                          context.push('/paywall');
                        },
                        child: const Text('اشترك الآن', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

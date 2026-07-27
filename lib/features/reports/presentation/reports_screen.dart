import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../data/reports_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/data/auth_repository.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsService = ref.watch(reportsServiceProvider);
    final currentCurrency = ref.watch(currencyProvider);

    if (reportsService == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dailySales = reportsService.getDailySales();
    final bestSellers = reportsService.getBestSellers();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text_104, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: AppLocalizations.of(context)!.text_105,
                    value: '${reportsService.totalRevenue} ${currentCurrency.code}',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                  ),
                ),
                if (ref.read(appUserProvider).value?.role != 'cashier') ...[
                  SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: AppLocalizations.of(context)!.text_106,
                      value: '${reportsService.netProfit} ${currentCurrency.code}',
                      icon: Icons.savings,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: AppLocalizations.of(context)!.text_66,
                    value: '${reportsService.totalExpenses} ${currentCurrency.code}',
                    icon: Icons.money_off,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: AppLocalizations.of(context)!.text_107,
                    value: '${reportsService.totalDebt} ${currentCurrency.code}',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Sales Chart
            Text(
              AppLocalizations.of(context)!.text_108,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            SizedBox(height: 16),
            GlassCard(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 250,
                child: dailySales.isEmpty 
                  ? Center(child: Text(AppLocalizations.of(context)!.text_109, style: TextStyle(fontFamily: 'Tajawal')))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < dailySales.length) {
                                  final date = dailySales[value.toInt()].date;
                                  return Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '${date.day}/${date.month}',
                                      style: TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
                                    ),
                                  );
                                }
                                return Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) => Text(
                                '${value.toInt()}',
                                style: TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
                              ),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: dailySales.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), e.value.amount);
                            }).toList(),
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
            SizedBox(height: 24),

            // Best Sellers
            Text(
              AppLocalizations.of(context)!.text_110,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            SizedBox(height: 16),
            if (bestSellers.isEmpty)
              Center(child: Text(AppLocalizations.of(context)!.text_109, style: TextStyle(fontFamily: 'Tajawal')))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bestSellers.take(5).length,
                itemBuilder: (context, index) {
                  final item = bestSellers[index];
                  return GlassCard(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                        child: Text('${index + 1}', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(item.product.name, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.quantitySold} وحدة مباعة', style: TextStyle(fontFamily: 'Tajawal')),
                      trailing: Text(
                        '${item.totalRevenue} ${currentCurrency.code}',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontFamily: 'Tajawal'),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../data/reports_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/pdf_service.dart';
import 'package:printing/printing.dart';
import '../../../core/services/excel_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedFilter = 'اليوم';

  ReportsService _getFilteredService(ReportsService service) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedFilter) {
      case 'اليوم':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'أسبوع':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'شهر':
        start = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'ربع سنوي':
        start = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'نصف سنوي':
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'سنة':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    return service.filterByDate(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final baseReportsService = ref.watch(reportsServiceProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canViewCost = appUser?.hasPermission('can_view_cost') ?? false;

    if (baseReportsService == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final reportsService = _getFilteredService(baseReportsService);
    final dailySales = reportsService.getDailySales();
    final bestSellers = reportsService.getBestSellers();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text104, style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          IconButton(
            icon: Icon(Icons.table_view, color: Colors.green),
            onPressed: () async {
              if (reportsService == null) return;
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('جاري تجهيز التقرير (إكسل)...', style: TextStyle(fontFamily: 'Tajawal'))),
                );
                await ExcelService.exportToExcel(reportsService, currentCurrency.code);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ أثناء تصدير إكسل: $e', style: TextStyle(fontFamily: 'Tajawal'))),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.red),
            onPressed: () async {
              if (reportsService == null) return;
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('جاري تجهيز التقرير (PDF)...', style: TextStyle(fontFamily: 'Tajawal'))),
                );
                final pdfData = await PdfService.generateReportPdf(reportsService, _selectedFilter, currentCurrency.code);
                await Printing.sharePdf(bytes: pdfData, filename: 'report.pdf');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ أثناء استخراج التقرير', style: TextStyle(fontFamily: 'Tajawal'))),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter and PDF Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _selectedFilter,
                  items: ['اليوم', 'أسبوع', 'شهر', 'ربع سنوي', 'نصف سنوي', 'سنة'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(fontFamily: 'Tajawal')),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedFilter = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: AppLocalizations.of(context)!.text105,
                    value: '${reportsService.totalRevenue} ${currentCurrency.code}',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                  ),
                ),
                if (canViewCost) ...[
                  SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: AppLocalizations.of(context)!.text106,
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
                    title: AppLocalizations.of(context)!.text66,
                    value: '${reportsService.totalExpenses} ${currentCurrency.code}',
                    icon: Icons.money_off,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: AppLocalizations.of(context)!.text107,
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
              AppLocalizations.of(context)!.text108,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            SizedBox(height: 16),
            GlassCard(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 250,
                child: dailySales.isEmpty 
                  ? Center(child: Text(AppLocalizations.of(context)!.text109, style: TextStyle(fontFamily: 'Tajawal')))
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
                                  int skip = (dailySales.length / 6).ceil();
                                  if (skip == 0) skip = 1;
                                  if (value.toInt() % skip != 0 && value.toInt() != dailySales.length - 1) return const Text('');
                                  
                                  final date = dailySales[value.toInt()].date;
                                  return Padding(
                                    padding: EdgeInsets.only(top: 8.0, right: 12.0),
                                    child: Transform.rotate(
                                      angle: -0.5,
                                      child: Text(
                                        '${date.day}/${date.month}',
                                        style: TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 40,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                String text;
                                if (value >= 1000) {
                                  text = '${(value / 1000).toStringAsFixed(1)}k';
                                } else {
                                  text = value.toInt().toString();
                                }
                                return Text(
                                  text,
                                  style: TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
                                );
                              },
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

            // Expenses Pie Chart
            Text(
              'توزيع المصروفات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            SizedBox(height: 16),
            Builder(
              builder: (context) {
                final expensesByCategory = reportsService.getExpensesByCategory();
                if (expensesByCategory.isEmpty) {
                  return GlassCard(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      height: 200,
                      child: Center(child: Text('لا توجد مصروفات في هذه الفترة', style: TextStyle(fontFamily: 'Tajawal'))),
                    ),
                  );
                }

                final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
                int colorIndex = 0;
                List<PieChartSectionData> expenseSections = [];
                expensesByCategory.forEach((category, amount) {
                  expenseSections.add(
                    PieChartSectionData(
                      color: colors[colorIndex % colors.length],
                      value: amount,
                      title: '${amount.toStringAsFixed(0)}',
                      radius: 60,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Tajawal'),
                    ),
                  );
                  colorIndex++;
                });

                return GlassCard(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: expensesByCategory.keys.toList().asMap().entries.map((entry) {
                          final color = colors[entry.key % colors.length];
                          final category = entry.value;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              SizedBox(width: 4),
                              Text(category, style: TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }
            ),
            SizedBox(height: 24),

            // Best Sellers
            Text(
              AppLocalizations.of(context)!.text110,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            SizedBox(height: 16),
            if (bestSellers.isEmpty)
              Center(child: Text(AppLocalizations.of(context)!.text109, style: TextStyle(fontFamily: 'Tajawal')))
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


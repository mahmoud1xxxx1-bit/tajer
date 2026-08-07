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
import '../../../core/widgets/tax_dialog.dart';
import '../../../core/providers/store_profile_provider.dart';

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
      case 'أمس':
        start = DateTime(now.year, now.month, now.day - 1);
        end = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case 'قبل يومين':
        start = DateTime(now.year, now.month, now.day - 2);
        end = DateTime(now.year, now.month, now.day - 2, 23, 59, 59);
        break;
      case 'أسبوع':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'شهر':
        start = DateTime(now.year, now.month - 1, now.day);
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

    final isAr = Localizations.localeOf(context).languageCode == 'ar';

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
                  SnackBar(content: Text(isAr ? 'جاري تجهيز التقرير (إكسل)...' : 'Preparing Excel report...', style: const TextStyle(fontFamily: 'Tajawal'))),
                );
                await ExcelService.exportToExcel(reportsService, currentCurrency.code);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAr ? 'حدث خطأ أثناء تصدير إكسل: $e' : 'Error exporting to Excel: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.red),
            onPressed: () async {
              if (reportsService == null) return;
              
              final storeProfile = ref.read(storeProfileProvider).value;
              double taxPercentage = storeProfile?.defaultTaxPercentage ?? 0.0;
              bool isInclusive = false; // default for reports if not set
              String vatNumber = storeProfile?.vatNumber ?? '';

              if (storeProfile?.defaultTaxPercentage == null || storeProfile?.defaultTaxPercentage == 0.0) {
                final result = await TaxDialog.show(context, showVatNumberField: vatNumber.isEmpty);
                if (result == null) return; // user cancelled
                taxPercentage = result.percentage;
                isInclusive = result.isInclusive;
                if (result.vatNumber != null && result.vatNumber!.isNotEmpty) {
                  vatNumber = result.vatNumber!;
                }
              }
              }

              try {
                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAr ? 'جاري تجهيز التقرير (PDF)...' : 'Preparing PDF Report...', style: const TextStyle(fontFamily: 'Tajawal'))),
                );
                final pdfData = await PdfService.generateReportPdf(
                  reportsService, 
                  _selectedFilter, 
                  currentCurrency.code,
                  taxPercentage: taxPercentage,
                  isInclusive: isInclusive,
                  vatNumber: vatNumber,
                  isAr: isAr,
                );
                await Printing.sharePdf(bytes: pdfData, filename: 'report.pdf');
              } catch (e) {
                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAr ? 'حدث خطأ أثناء استخراج التقرير' : 'Error generating report', style: const TextStyle(fontFamily: 'Tajawal'))),
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
                  items: ['اليوم', 'أمس', 'قبل يومين', 'أسبوع', 'شهر', 'نصف سنوي', 'سنة'].map((String value) {
                    String displayValue = value;
                    if (!isAr) {
                      switch (value) {
                        case 'اليوم': displayValue = 'Today'; break;
                        case 'أمس': displayValue = 'Yesterday'; break;
                        case 'قبل يومين': displayValue = '2 days ago'; break;
                        case 'أسبوع': displayValue = 'Week'; break;
                        case 'شهر': displayValue = 'Month'; break;
                        case 'نصف سنوي': displayValue = 'Half year'; break;
                        case 'سنة': displayValue = 'Year'; break;
                      }
                    }
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(displayValue, style: const TextStyle(fontFamily: 'Tajawal')),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      if (newValue == 'نصف سنوي' || newValue == 'سنة') {
                        // Heavy data: warn user and recommend website
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(isAr ? 'بيانات ضخمة' : 'Large Data', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isAr 
                                    ? 'هذه البيانات كبيرة جداً وقد تسبب بطء أو تعليق في الجوال. يرجى التوجه إلى موقع التاجر واستخراجها من جهاز الكمبيوتر لضمان أفضل أداء.'
                                    : 'This data is very large and might cause lag on your phone. Please use the Tajer website on your computer for better performance.',
                                  style: const TextStyle(fontFamily: 'Tajawal'),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    'https://alldown.uk/taj/',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedFilter = newValue;
                                  });
                                },
                                child: Text(isAr ? 'متابعة على أي حال' : 'Continue Anyway', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(isAr ? 'حسناً' : 'OK', style: const TextStyle(fontFamily: 'Tajawal')),
                              ),
                            ],
                          ),
                        );
                      } else {
                        setState(() {
                          _selectedFilter = newValue;
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _SummaryCard(
                        title: isAr ? 'صافي المبيعات' : 'Net Sales',
                        value: '${reportsService.netSalesRevenue.toStringAsFixed(2)} ${currentCurrency.code}',
                        icon: Icons.account_balance_wallet,
                        color: Colors.green,
                      ),
                    ),
                    if (reportsService.totalTaxCollected > 0)
                      SizedBox(
                        width: cardWidth,
                        child: _SummaryCard(
                          title: isAr ? 'الضريبة المحصلة' : 'Tax Collected',
                          value: '${reportsService.totalTaxCollected.toStringAsFixed(2)} ${currentCurrency.code}',
                          icon: Icons.receipt_long,
                          color: Colors.purple,
                        ),
                      ),
                    if (canViewCost)
                      SizedBox(
                        width: cardWidth,
                        child: _SummaryCard(
                          title: AppLocalizations.of(context)!.text106,
                          value: '${reportsService.netProfit.toStringAsFixed(2)} ${currentCurrency.code}',
                          icon: Icons.trending_up,
                          color: Colors.blue,
                        ),
                      ),
                    SizedBox(
                      width: cardWidth,
                      child: _SummaryCard(
                        title: AppLocalizations.of(context)!.text66,
                        value: '${reportsService.totalExpenses.toStringAsFixed(2)} ${currentCurrency.code}',
                        icon: Icons.money_off,
                        color: Colors.orange,
                      ),
                    ),
                    if (canViewCost)
                      SizedBox(
                        width: cardWidth,
                        child: _SummaryCard(
                          title: isAr ? 'تكلفة البضاعة المباعة (COGS)' : 'Cost of Goods Sold (COGS)',
                          value: '${reportsService.totalCOGS.toStringAsFixed(2)} ${currentCurrency.code}',
                          icon: Icons.inventory_2_outlined,
                          color: Colors.brown,
                        ),
                      ),
                    SizedBox(
                      width: cardWidth,
                      child: _SummaryCard(
                        title: AppLocalizations.of(context)!.text107,
                        value: '${reportsService.totalDebt.toStringAsFixed(2)} ${currentCurrency.code}',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                );
              },
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
                  : BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < dailySales.length) {
                                  int skip = (dailySales.length / 5).ceil();
                                  if (skip == 0) skip = 1;
                                  if (value.toInt() % skip != 0 && value.toInt() != dailySales.length - 1) return const Text('');
                                  
                                  final date = dailySales[value.toInt()].date;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                                    child: Transform.rotate(
                                      angle: -0.5,
                                      child: Text(
                                        '${date.day}/${date.month}',
                                        style: const TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 55,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max || value == meta.min && value != 0) {
                                  return const SizedBox.shrink();
                                }
                                String text;
                                if (value >= 1000) {
                                  text = '${(value / 1000).toStringAsFixed(1)}k';
                                } else {
                                  text = value.toInt().toString();
                                }
                                return Text(
                                  text,
                                  style: const TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: dailySales.asMap().entries.map((e) {
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.amount,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                width: dailySales.length <= 3 ? 30 : 16,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: dailySales.isEmpty ? 100 : (dailySales.map((d) => d.amount).reduce((a, b) => a > b ? a : b) * 1.1).clamp(100.0, double.infinity),
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
              ),
            ),
            SizedBox(height: 24),

            // Expenses Pie Chart
            Text(
              isAr ? 'توزيع المصروفات' : 'Expenses Distribution',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
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
                      child: Center(child: Text(isAr ? 'لا توجد مصروفات في هذه الفترة' : 'No expenses in this period', style: const TextStyle(fontFamily: 'Tajawal'))),
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
                      subtitle: Text(isAr ? '${item.quantitySold} وحدة مباعة' : '${item.quantitySold} units sold', style: const TextStyle(fontFamily: 'Tajawal')),
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return SizedBox(
      height: 120, // Fixed height as requested
      child: GlassCard(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 22),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12, fontFamily: 'Tajawal', height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
            Spacer(),
            Align(
              alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


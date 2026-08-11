import 'package:tajer/features/action_center/data/action_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/application/access_policy.dart';
import '../../branches/presentation/branch_context.dart';
import '../../branches/data/branch_repository.dart';
import '../../branches/domain/branch.dart';
import '../../products/data/product_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../reports/data/reports_service.dart';
import '../data/business_overview_repository.dart';

final overviewPeriodProvider = StateProvider<String>((ref) => 'today');

final overviewDateRangeProvider = Provider<DateTimeRange>((ref) {
  final period = ref.watch(overviewPeriodProvider);
  final now = DateTime.now();
  DateTime start;
  DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

  switch (period) {
    case 'today':
      start = DateTime(now.year, now.month, now.day);
      break;
    case 'yesterday':
      start = DateTime(now.year, now.month, now.day - 1);
      end = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
      break;
    case 'last7Days':
      start = now.subtract(const Duration(days: 7));
      break;
    case 'last30Days':
      start = now.subtract(const Duration(days: 30));
      break;
    default:
      start = DateTime(now.year, now.month, now.day);
  }
  return DateTimeRange(start: start, end: end);
});

final overviewReportsServiceProvider = FutureProvider<ReportsService?>((ref) async {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null || !policy.isOwnerLike) {
    return null;
  }
  
  final merchantId = currentEffectiveMerchantId(appUser);
  final range = ref.watch(overviewDateRangeProvider);
  
  final repo = ref.watch(businessOverviewRepositoryProvider);
  final orders = await repo.getOrders(merchantId, range.start, range.end);
  final expenses = await repo.getExpenses(merchantId, range.start, range.end);
  final debtPayments = await repo.getDebtPayments(merchantId, range.start, range.end);
  
  // Reuse existing streams for bounded reference data
  final products = ref.watch(productsStreamProvider).value ?? [];
  final customers = ref.watch(customersStreamProvider).value ?? [];
  final suppliers = ref.watch(suppliersStreamProvider).value ?? [];
  
  // Use merchantOrderCostsProvider for protected costs
  final protectedCosts = ref.watch(merchantOrderCostsProvider).value ?? {};
  final storeProfile = ref.watch(storeProfileProvider).value;

  return ReportsService(
    orders,
    products,
    expenses,
    customers,
    suppliers,
    debtPayments: debtPayments,
    protectedOrderCosts: protectedCosts,
    canViewCost: policy.canViewCosts,
    defaultTaxPercentage: storeProfile?.defaultTaxPercentage ?? 0.0,
    defaultIsTaxInclusive: storeProfile?.defaultIsTaxInclusive ?? true,
  );
});

class BusinessOverviewScreen extends ConsumerWidget {
  const BusinessOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final policy = ref.watch(accessPolicyProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    
    if (!policy.isOwnerLike) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.businessOverview ?? 'Business Overview', style: const TextStyle(fontFamily: 'Tajawal'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr ? 'ليس لديك صلاحية لعرض هذا القسم' : 'You do not have permission to view this section',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.businessOverview ?? 'Business Overview', style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _PeriodSelector()),
          SliverToBoxAdapter(child: _HealthSection()),
          SliverToBoxAdapter(child: _MetricsSection()),
          SliverToBoxAdapter(child: _BranchPerformanceSection()),
          SliverToBoxAdapter(child: _MoneyPositionSection()),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentPeriod = ref.watch(overviewPeriodProvider);
    
    final periods = {
      'today': l10n.today ?? 'Today',
      'yesterday': l10n.yesterday ?? 'Yesterday',
      'last7Days': l10n.last7Days ?? 'Last 7 Days',
      'last30Days': l10n.last30Days ?? 'Last 30 Days',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: periods.entries.map((entry) {
          final isSelected = currentPeriod == entry.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(entry.value, style: const TextStyle(fontFamily: 'Tajawal')),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(overviewPeriodProvider.notifier).state = entry.key;
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HealthSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeBranchId = ref.watch(selectedBranchIdProvider);
    final alertsAsync = ref.watch(openAlertsProvider(activeBranchId ?? 'main'));
    
    int lowStockCount = 0;
    int reorderCount = 0;
    int outOfStockCount = 0;
    int attentionCount = 0;
    
    if (alertsAsync.hasValue) {
      final alerts = alertsAsync.value!;
      for (final alert in alerts) {
        if (alert.type == 'low_stock') {
          lowStockCount++;
        } else if (alert.type == 'reorder_needed' || alert.type == 'reorder_configuration_required') {
          reorderCount++;
        } else if (alert.type == 'out_of_stock') {
          outOfStockCount++;
        } else if (alert.type == 'stocktake_conflict') {
          // Only count stocktake conflicts for the currently active branch
          if (alert.branchId == activeBranchId) {
            attentionCount++;
          }
        } else {
          attentionCount++;
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.inventoryHealth ?? 'Inventory Health', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _HealthIcon(
                      icon: Icons.warning_amber, 
                      label: l10n.lowStock ?? 'Low Stock', 
                      count: lowStockCount, 
                      color: Colors.orange,
                      onTap: () => context.push('/reorder_center')),
                  _HealthIcon(
                      icon: Icons.shopping_cart_outlined, 
                      label: l10n.needsReorder ?? 'Needs Reorder', 
                      count: reorderCount, 
                      color: Colors.blue,
                      onTap: () => context.push('/reorder_center')),
                  _HealthIcon(
                      icon: Icons.error_outline, 
                      label: l10n.outOfStock ?? 'Out of Stock', 
                      count: outOfStockCount, 
                      color: Colors.red,
                      onTap: () => context.push('/action_center')),
                  _HealthIcon(
                      icon: Icons.report_problem, 
                      label: l10n.attentionRequired ?? 'Action Center', 
                      count: attentionCount, 
                      color: Colors.purple,
                      onTap: () => context.push('/action_center')),
                  _HealthIcon(
                      icon: Icons.summarize, 
                      label: l10n.dailySummaries ?? 'Daily Summaries', 
                      count: 0, 
                      color: Colors.teal,
                      onTap: () => context.push('/daily_summaries')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HealthIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  
  const _HealthIcon({required this.icon, required this.label, required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Icon(icon, size: 36, color: color),
            if (count > 0)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10), textAlign: TextAlign.center),
      ],
    ),
    );
  }
}

class _MetricsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider);
    final reportsAsync = ref.watch(overviewReportsServiceProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: reportsAsync.when(
        data: (reports) {
          if (reports == null) return const SizedBox.shrink();
          
          final profit = reports.netProfit;
          final cogs = reports.totalCOGS;
          
          final currencyFormat = NumberFormat.currency(symbol: currency.code, decimalDigits: 2);
          
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _MetricCard(title: l10n.totalSales, value: currencyFormat.format(reports.netSalesRevenue), icon: Icons.attach_money, color: Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _MetricCard(title: l10n.ordersCount, value: '${reports.orders.where((o) => o.status != 'cancelled' && o.status != 'debt_repayment').length}', icon: Icons.shopping_bag, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _MetricCard(title: l10n.expenses, value: currencyFormat.format(reports.totalExpenses), icon: Icons.money_off, color: Colors.red)),
                  const SizedBox(width: 8),
                  Expanded(child: _MetricCard(title: 'VAT', value: currencyFormat.format(reports.totalTaxCollected), icon: Icons.account_balance, color: Colors.purple)),
                ],
              ),
              const SizedBox(height: 8),
              if (reports.canViewCost)
                Row(
                  children: [
                    Expanded(child: _MetricCard(title: 'COGS', value: reports.isCOGSComplete ? currencyFormat.format(cogs) : (l10n.costDataIncomplete ?? 'Incomplete'), icon: Icons.inventory, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(child: _MetricCard(title: l10n.text106, value: reports.isCOGSComplete ? currencyFormat.format(profit) : (l10n.costDataIncomplete ?? 'Incomplete'), icon: Icons.trending_up, color: Colors.teal)),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Text('Error: $e'),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BranchPerformanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final branchesAsync = ref.watch(branchesStreamProvider);
    final reportsAsync = ref.watch(overviewReportsServiceProvider);
    final currency = ref.watch(currencyProvider);
    
    if (branchesAsync.isLoading || reportsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final branches = branchesAsync.value ?? [];
    final reports = reportsAsync.value;
    if (reports == null || branches.isEmpty) return const SizedBox.shrink();
    
    final branchStats = <String, Map<String, dynamic>>{};
    
    for (final branch in branches) {
      branchStats[branch.id] = {
        'name': branch.name,
        'sales': 0.0,
        'orders': 0,
        'expenses': 0.0,
        'profit': 0.0,
        'cogs': 0.0,
        'cogsComplete': true,
      };
    }
    
    for (final order in reports.orders) {
      if (order.status == 'cancelled' || order.status == 'debt_repayment') continue;
      final bId = order.branchId;
      if (branchStats.containsKey(bId)) {
        branchStats[bId]!['sales'] += reports.getOrderEffectiveRevenue(order);
        branchStats[bId]!['orders'] += 1;
        
        branchStats[bId]!['cogs'] += reports.getOrderEffectiveCOGS(order);
        
        final protected = reports.protectedOrderCosts[order.id];
        if (protected == null) {
          if (order.items.isNotEmpty && order.items.any((item) => item.costPrice == null)) {
            branchStats[bId]!['cogsComplete'] = false;
          }
        }
      }
    }
    
    for (final expense in reports.expenses) {
      if (expense.isCancelled || expense.isSupplierPayment) continue;
      final bId = expense.branchId ?? 'main';
      if (branchStats.containsKey(bId)) {
        branchStats[bId]!['expenses'] += expense.amount;
      }
    }
    
    final sortedBranches = branchStats.values.toList()
      ..sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));
      
    final currencyFormat = NumberFormat.currency(symbol: currency.code, decimalDigits: 2);
      
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.branchPerformance ?? 'Branch Performance', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...sortedBranches.map((stats) {
            final sales = stats['sales'] as double;
            final expenses = stats['expenses'] as double;
            final cogs = stats['cogs'] as double;
            final isComplete = stats['cogsComplete'] as bool;
            final profit = sales - expenses - cogs; // Simplified for display
            
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(stats['name'], style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                      Text(currencyFormat.format(sales), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${l10n.ordersCount}: ${stats['orders']}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      Text('${l10n.expenses}: ${currencyFormat.format(expenses)}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.red)),
                      if (reports.canViewCost)
                        Text('${l10n.text106}: ${isComplete ? currencyFormat.format(profit) : (l10n.costDataIncomplete ?? "-")}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.teal)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _MoneyPositionSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(overviewReportsServiceProvider);
    final currency = ref.watch(currencyProvider);
    
    if (reportsAsync.isLoading) return const SizedBox.shrink();
    final reports = reportsAsync.value;
    if (reports == null) return const SizedBox.shrink();
    
    final customerDebt = reports.totalDebt;
    
    // We get supplier debt globally because suppliers are merchant-wide
    final suppliers = reports.suppliers;
    final supplierDebt = suppliers.fold<double>(0, (sum, s) => sum + s.totalDebt);

    final currencyFormat = NumberFormat.currency(symbol: currency.code, decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.moneyPosition ?? 'Money Position', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Icon(Icons.call_received, color: Colors.green),
                      const SizedBox(height: 4),
                      Text(l10n.customerReceivables ?? 'Customer Receivables', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(currencyFormat.format(customerDebt), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Icon(Icons.call_made, color: Colors.red),
                      const SizedBox(height: 4),
                      Text(l10n.supplierPayables ?? 'Supplier Payables', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(currencyFormat.format(supplierDebt), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

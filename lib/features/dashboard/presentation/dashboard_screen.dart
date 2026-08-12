import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../products/presentation/products_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../orders/presentation/pos_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../orders/data/order_repository.dart';
import '../../products/data/product_repository.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/store_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/services/app_review_service.dart';
import '../../../core/widgets/app_drawer.dart';
import 'setup_checklist_card.dart';
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppReviewService.instance.checkAndPromptForReview(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.watch(appUserProvider).value;
    final themeMode = ref.watch(themeProvider); // Force rebuild on theme change
    
    final bool canManageCustomers = appUser?.hasPermission('can_manage_customers') ?? false;
    final bool canViewReports = appUser?.hasPermission('can_view_reports') ?? false;
    final bool canCreateOrders = appUser?.hasPermission('can_create_orders') ?? false;

    final List<Widget> screens = [
      DashboardHome(
        canManageCustomers: canManageCustomers,
        canViewReports: canViewReports,
        canCreateOrders: canCreateOrders,
        onNavigateToTab: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      OrdersScreen(), // Removed const to ensure rebuild
      ProductsScreen(),
      if (canManageCustomers) CustomersScreen(),
      if (canViewReports) ReportsScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.confirmExit, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
            content: Text(l10n.confirmExitMessage, style: TextStyle(fontFamily: 'Tajawal')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel, style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                child: Text(l10n.exit, style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          ),
        );
        if (shouldPop ?? false) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: l10n.orders,
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: l10n.products,
          ),
          if (canManageCustomers)
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: l10n.customers,
            ),
          if (canViewReports)
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: l10n.reports,
            ),
        ],
      ),
      ),
    );
  }
}


class DashboardHome extends ConsumerWidget {
  final void Function(int) onNavigateToTab;
  final bool canManageCustomers;
  final bool canViewReports;
  final bool canCreateOrders;
  const DashboardHome({super.key, required this.onNavigateToTab, required this.canManageCustomers, required this.canViewReports, required this.canCreateOrders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final storeProfile = ref.watch(storeProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard, style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          if (appUser?.role != 'employee')
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: ordersAsync.when(
        data: (orders) {
          final activeOrders = orders.where((o) => o.status != 'cancelled' && o.status != 'debt_repayment').toList();
          final totalSales = activeOrders.fold<double>(0, (sum, order) => sum + order.total);
          final ordersCount = activeOrders.length;

          // Low stock calculation and widget
          Widget? lowStockWidget;
          if (productsAsync.hasError) {
            lowStockWidget = Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.errorFetchingInventory,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                    ),
                  ),
                ],
              ),
            );
          } else {
            final lowStockProducts = productsAsync.value?.where((p) => !p.isManufacturedOnDemand && p.quantity <= 5).toList() ?? [];
            if (lowStockProducts.isNotEmpty) {
              lowStockWidget = Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.lowStockAlert(lowStockProducts.length.toString()),
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigateToTab(2),
                      child: Text(AppLocalizations.of(context)!.text63, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                    ),
                  ],
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: ListView(
              children: [
                if (storeProfile?.storeName.isEmpty ?? true) ...[
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.completeStoreBrandingAlert,
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.push('/store_branding');
                          },
                          child: Text(l10n.completeNow, style: TextStyle(color: Colors.orange, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
                SetupChecklistCard(onNavigateToTab: onNavigateToTab),
                if (lowStockWidget != null) lowStockWidget,
                Text(
                  l10n.reports,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: l10n.totalSales,
                        value: '$totalSales ${currentCurrency.code}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: l10n.ordersCount,
                        value: '$ordersCount',
                        icon: Icons.shopping_bag_outlined,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),


                Text(
                  l10n.quickActions,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
                SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 8,
                  runSpacing: 16,
                  children: [
                    if (canCreateOrders)
                      _QuickAction(
                        icon: Icons.point_of_sale,
                        label: l10n.posCashier,
                        color: Colors.green,
                        onTap: () async {
                          final shouldGoToOrders = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (context) => const PosScreen()),
                          );
                          if (shouldGoToOrders == true) {
                            onNavigateToTab(1); // 1 is the index of Orders tab
                          }
                        },
                      ),
                    _QuickAction(
                      icon: Icons.add_shopping_cart,
                      label: l10n.orders,
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () {
                        onNavigateToTab(1);
                      },
                    ),
                    _QuickAction(
                      icon: Icons.inventory_2_outlined,
                      label: l10n.products,
                      color: Colors.deepPurpleAccent,
                      onTap: () {
                        onNavigateToTab(2);
                      },
                    ),
                    _QuickAction(
                      icon: Icons.person_outline,
                      label: l10n.customers,
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () {
                        onNavigateToTab(3);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  l10n.managementAndInventory,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
                SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 8,
                  runSpacing: 16,
                  children: [
                    _QuickAction(
                      icon: Icons.money_off,
                      label: l10n.expenses,
                      color: Colors.redAccent,
                      onTap: () {
                        context.push('/expenses');
                      },
                    ),
                    _QuickAction(
                      icon: Icons.business,
                      label: l10n.suppliers,
                      color: Colors.blueAccent,
                      onTap: () {
                        context.push('/suppliers');
                      },
                    ),
                    _QuickAction(
                      icon: Icons.category,
                      label: l10n.categories,
                      color: Colors.orangeAccent,
                      onTap: () {
                        context.push('/categories');
                      },
                    ),
                    _QuickAction(
                      icon: Icons.history,
                      label: l10n.inventoryLog,
                      color: Colors.purpleAccent,
                      onTap: () {
                        context.push('/inventory_logs');
                      },
                    ),
                  ],
                ),
                if (appUser?.role != 'employee') ...[
                  SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
                    runSpacing: 16,
                    children: [
                      _QuickAction(
                        icon: Icons.archive,
                        label: Localizations.localeOf(context).languageCode == 'ar' ? 'أرشيف الورديات' : 'Shifts Archive',
                        color: Colors.brown,
                        onTap: () {
                          context.push('/shifts_archive');
                        },
                      ),

                    ],
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.errorPrefix(e.toString()))),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150, // Fixed height to prevent expanding
      child: GlassCard(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            SizedBox(height: 12),
            Text(title, style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          GlassCard(
            width: 70,
            height: 70,
            child: Icon(icon, color: color, size: 30),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

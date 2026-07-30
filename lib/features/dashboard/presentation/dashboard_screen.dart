import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../products/presentation/products_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../orders/data/order_repository.dart';
import '../../products/data/product_repository.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> screens = [
      DashboardHome(onNavigateToTab: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      const OrdersScreen(),
      const ProductsScreen(),
      const CustomersScreen(),
      const ReportsScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('تأكيد الخروج', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
            content: Text('هل أنت متأكد أنك تريد الخروج من التطبيق؟', style: TextStyle(fontFamily: 'Tajawal')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                child: Text('خروج', style: TextStyle(fontFamily: 'Tajawal')),
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
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: l10n.customers,
          ),
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
  const DashboardHome({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;

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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
              ),
              child: Text(l10n.managementAndInventory, style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'Tajawal')),
            ),
            if (appUser?.hasPermission('can_manage_expenses') ?? false)
            ListTile(
              leading: Icon(Icons.money_off),
              title: Text(l10n.expenses, style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/expenses');
              },
            ),
            if (appUser?.hasPermission('can_manage_customers') ?? false)
            ListTile(
              leading: Icon(Icons.business),
              title: Text(l10n.suppliers, style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/suppliers');
              },
            ),
            if (appUser?.hasPermission('can_manage_products') ?? false)
            ListTile(
              leading: Icon(Icons.category),
              title: Text(l10n.categories, style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/categories');
              },
            ),
              if (appUser?.hasPermission('can_manage_inventory') ?? false)
              ListTile(
                leading: Icon(Icons.history),
                title: Text(l10n.inventoryLog, style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/inventory_logs');
                },
              ),
              if (appUser?.role != 'employee')
              ListTile(
                leading: Icon(Icons.manage_accounts),
                title: Text('الموظفين والصلاحيات (Pro)', style: TextStyle(fontFamily: 'Tajawal', color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/employees');
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text(l10n.logout, style: TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) {
                    context.go('/auth');
                  }
                },
              ),
          ],
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          final totalSales = orders.fold<double>(0, (sum, order) => sum + order.total);
          final ordersCount = orders.length;

          // Low stock calculation
          final lowStockProducts = productsAsync.value?.where((p) => p.quantity <= 5).toList() ?? [];

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: ListView(
              children: [
                if (lowStockProducts.isNotEmpty) ...[
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تنبيه: يوجد ${lowStockProducts.length} منتج يوشك على النفاذ من المخزون!',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => onNavigateToTab(2), // 2 is Products tab
                          child: Text(AppLocalizations.of(context)!.text63, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                        ),
                      ],
                    ),
                  ),
                ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
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
                    _QuickAction(
                      icon: Icons.bar_chart_rounded,
                      label: l10n.reports,
                      color: Colors.teal,
                      onTap: () {
                        onNavigateToTab(4);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
              ],
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
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
    return GlassCard(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          SizedBox(height: 16),
          Text(title, style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 14)),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
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

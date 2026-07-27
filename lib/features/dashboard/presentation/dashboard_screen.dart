import 'package:flutter/material.dart';
import '../../products/presentation/products_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../orders/data/order_repository.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardHome(onNavigateToTab: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      const OrdersScreen(),
      const ProductsScreen(),
      const CustomersScreen(),
    ];

    return Scaffold(
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'الطلبات',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'المنتجات',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'العملاء',
          ),
        ],
      ),
    );
  }
}

class DashboardHome extends ConsumerWidget {
  final void Function(int) onNavigateToTab;
  const DashboardHome({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم', style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final totalSales = orders.fold<double>(0, (sum, order) => sum + order.total);
          final ordersCount = orders.length;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ملخص الأداء',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'إجمالي المبيعات',
                        value: '$totalSales ${currentCurrency.code}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'عدد الطلبات',
                        value: '$ordersCount',
                        icon: Icons.shopping_bag_outlined,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'أوامر سريعة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickAction(
                      icon: Icons.add_shopping_cart,
                      label: 'الطلبات',
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () {
                        onNavigateToTab(1);
                      },
                    ),
                    _QuickAction(
                      icon: Icons.inventory_2_outlined,
                      label: 'المنتجات',
                      color: Colors.deepPurpleAccent,
                      onTap: () {
                        onNavigateToTab(2);
                      },
                    ),
                    _QuickAction(
                      icon: Icons.person_outline,
                      label: 'العملاء',
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () {
                        onNavigateToTab(3);
                      },
                    ),
                  ],
                )
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../../core/theme/glass_card.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/data/auth_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              if (index == 2) {
                // Logout logic
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('الرئيسية', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('التجار', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Consumer(
                    builder: (context, ref, _) {
                      return IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: () {
                          ref.read(authRepositoryProvider).signOut();
                          context.go('/');
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: _selectedIndex == 0
                ? const AdminDashboardView()
                : const MerchantsListView(),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الإدارة العليا', style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: Colors.transparent,
      ),
      body: statsAsync.when(
        data: (stats) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إحصائيات المنصة الكلية',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _AdminStatCard(
                        title: 'التجار المسجلين',
                        value: '${stats['totalMerchants']}',
                        icon: Icons.storefront,
                        color: Colors.deepPurple,
                      ),
                      _AdminStatCard(
                        title: 'المنتجات المدخلة',
                        value: '${stats['totalProducts']}',
                        icon: Icons.inventory,
                        color: Colors.orange,
                      ),
                      _AdminStatCard(
                        title: 'الطلبات المنفذة',
                        value: '${stats['totalOrders']}',
                        icon: Icons.shopping_bag,
                        color: Colors.blue,
                      ),
                      _AdminStatCard(
                        title: 'العملاء المسجلين',
                        value: '${stats['totalCustomers']}',
                        icon: Icons.people,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
      ),
    );
  }
}

class MerchantsListView extends ConsumerWidget {
  const MerchantsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(merchantsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التجار', style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: Colors.transparent,
      ),
      body: merchantsAsync.when(
        data: (merchants) {
          if (merchants.isEmpty) {
            return const Center(child: Text('لا يوجد تجار مسجلين.', style: TextStyle(fontFamily: 'Tajawal')));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: merchants.length,
            itemBuilder: (context, index) {
              final merchant = merchants[index];
              final isGuest = merchant.isAnonymous;
              
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isGuest ? Colors.grey : Colors.deepPurple,
                    child: Icon(isGuest ? Icons.person_outline : Icons.store, color: Colors.white),
                  ),
                  title: Text(
                    merchant.name ?? merchant.email ?? 'تاجر مجهول',
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'الباقة: ${merchant.plan} | الانضمام: ${merchant.createdAt.toString().split(' ')[0]}',
                    style: const TextStyle(fontFamily: 'Tajawal'),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'upgrade') {
                        ref.read(adminRepositoryProvider).updateMerchantPlan(merchant.id, 'premium');
                        ref.invalidate(merchantsListProvider);
                      } else if (value == 'downgrade') {
                        ref.read(adminRepositoryProvider).updateMerchantPlan(merchant.id, 'guest');
                        ref.invalidate(merchantsListProvider);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'upgrade',
                        child: Text('ترقية إلى Premium', style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                      const PopupMenuItem(
                        value: 'downgrade',
                        child: Text('إرجاع إلى Guest', style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AdminStatCard({
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

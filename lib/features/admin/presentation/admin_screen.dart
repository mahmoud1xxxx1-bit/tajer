import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الإدارة العليا (Super Admin)', style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: statsAsync.when(
        data: (stats) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'إحصائيات المنصة',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2,
                    children: [
                      _AdminStatCard(
                        title: 'إجمالي المنتجات',
                        value: '${stats['totalProducts']}',
                        icon: Icons.inventory,
                        color: Colors.orange,
                      ),
                      _AdminStatCard(
                        title: 'إجمالي الطلبات',
                        value: '${stats['totalOrders']}',
                        icon: Icons.shopping_bag,
                        color: Colors.blue,
                      ),
                      _AdminStatCard(
                        title: 'إجمالي العملاء',
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/data/auth_repository.dart';

class InventoryManagementScreen extends ConsumerWidget {
  const InventoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final user = ref.watch(appUserProvider).value;
    final canManageInventory = user?.hasPermission('can_manage_inventory') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'إدارة المخزون' : 'Inventory Management'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.inventory_2_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'إدارة حركات المخزون وسجلها حسب الفرع. كل عملية تحفظ مصدرها والفرع الذي أثرت عليه.'
                          : 'Manage branch-scoped inventory movements and history. Every action keeps its provenance and affected branch.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InventoryActionCard(
            icon: Icons.history_rounded,
            title: isAr ? 'سجل حركات المخزون' : 'Inventory Movement History',
            subtitle: isAr
                ? 'راجع الإضافات والخصومات والتسويات ومن نفذ كل حركة.'
                : 'Review additions, deductions, adjustments, and who performed them.',
            onTap: () => context.push('/inventory_history'),
          ),
          const SizedBox(height: 12),
          _InventoryActionCard(
            icon: Icons.checklist_rtl_rounded,
            title: isAr ? 'الجرد الفعلي' : 'Physical Stocktake',
            subtitle: canManageInventory
                ? (isAr
                    ? 'جرد المنتجات والمواد الخام وتحديث الأرصدة دفعة واحدة.'
                    : 'Count products and raw materials to bulk-update inventory balances.')
                : (isAr
                    ? 'تحتاج صلاحية إدارة المخزون لتنفيذ الجرد.'
                    : 'Inventory management permission is required to perform stocktakes.'),
            enabled: canManageInventory,
            onTap: () => context.push('/stocktakes'),
          ),
          const SizedBox(height: 12),
          _InventoryActionCard(
            icon: Icons.swap_horiz_rounded,
            title: isAr ? 'تحويل المخزون بين الفروع' : 'Inter-Branch Stock Transfer',
            subtitle: canManageInventory
                ? (isAr
                    ? 'انقل المنتجات أو المواد الخام بأمان بين الفروع النشطة.'
                    : 'Move products or raw materials safely between active branches.')
                : (isAr
                    ? 'تحتاج صلاحية إدارة المخزون لتنفيذ التحويلات.'
                    : 'Inventory management permission is required to perform transfers.'),
            enabled: canManageInventory,
            onTap: () => context.push('/inventory_transfer'),
          ),
        ],
      ),
    );
  }
}

class _InventoryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _InventoryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

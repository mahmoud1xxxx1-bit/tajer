import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/application/session_controller.dart';
import '../../features/branches/presentation/active_branch_selector.dart';
import '../providers/store_profile_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.watch(appUserProvider).value;
    final storeProfile = ref.watch(storeProfileProvider).value;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade900, Colors.blueAccent],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (storeProfile?.logoBase64 != null &&
                          storeProfile!.logoBase64.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(storeProfile.logoBase64),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.storefront,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          (storeProfile?.storeName.isNotEmpty ?? false)
                              ? storeProfile!.storeName
                              : l10n.managementAndInventory,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: appUser?.role == 'employee'
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: appUser?.role == 'employee'
                            ? Colors.amberAccent
                            : Colors.greenAccent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appUser?.role == 'employee'
                              ? Icons.badge_outlined
                              : Icons.admin_panel_settings_outlined,
                          color: appUser?.role == 'employee'
                              ? Colors.amberAccent
                              : Colors.greenAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            appUser?.role == 'employee'
                                ? l10n.employeePrefix(appUser?.name ?? "")
                                : l10n.merchantAccount,
                            style: TextStyle(
                              color: appUser?.role == 'employee'
                                  ? Colors.amberAccent
                                  : Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (storeProfile?.phone != null &&
                      storeProfile!.phone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '📞 ${storeProfile.phone}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontFamily: 'Tajawal'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: ActiveBranchSelector(compact: true),
          ),
          if (appUser?.role != 'employee')
            ListTile(
              leading: const Icon(Icons.account_tree_rounded),
              title: Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'الفروع'
                    : 'Branches',
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/branches');
              },
            ),
          if (appUser?.hasPermission('can_manage_expenses') ?? false)
            ListTile(
              leading: const Icon(Icons.money_off),
              title: Text(l10n.expenses,
                  style: const TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/expenses');
              },
            ),
          if (appUser?.role != 'employee' &&
              (appUser?.hasPermission('can_manage_inventory') ?? false))
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: Text(l10n.rawMaterials,
                  style: const TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/raw_materials');
              },
            ),
          if (appUser?.role != 'employee' &&
              (appUser?.hasPermission('can_manage_inventory') ?? false))
            ListTile(
              leading: const Icon(Icons.business),
              title: Text(l10n.suppliers,
                  style: const TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/suppliers');
              },
            ),
          if (appUser?.hasPermission('can_manage_products') ?? false)
            ListTile(
              leading: const Icon(Icons.category),
              title: Text(l10n.categories,
                  style: const TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/categories');
              },
            ),
          if (appUser?.hasPermission('can_manage_inventory') ?? false)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.inventoryLog,
                  style: const TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/inventory_logs');
              },
            ),
          if (appUser?.role != 'employee')
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: Text(l10n.employeesPermissionsPro,
                  style: const TextStyle(
                      fontFamily: 'Tajawal', color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                context.push('/employees');
              },
            ),
          if (appUser?.role != 'employee')
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.settings,
                  style: const TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ListTile(
            leading: const Icon(Icons.lock_clock),
            title: Text(l10n.closeShiftZReport,
                style: const TextStyle(fontFamily: 'Tajawal')),
            onTap: () {
              Navigator.pop(context);
              context.push('/end_shift');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout,
                style:
                    const TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
            onTap: () async {
              await ref.read(sessionControllerProvider).logout();
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
        ],
      ),
    );
  }
}

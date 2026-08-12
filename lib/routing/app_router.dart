import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/application/access_policy.dart';
import '../features/authentication/application/session_identity.dart';
import '../features/authentication/presentation/startup_screen.dart';
import '../features/authentication/presentation/upgrade_account_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/products/presentation/raw_materials_screen.dart';
import '../features/subscriptions/presentation/paywall_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/backup_security_screen.dart';
import '../features/settings/presentation/printer_settings_screen.dart';
import '../features/settings/presentation/store_branding_screen.dart';
import '../features/expenses/presentation/expenses_screen.dart';
import '../features/suppliers/presentation/suppliers_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/inventory_log/presentation/inventory_logs_screen.dart';
import '../features/employees/presentation/employees_screen.dart';
import '../features/employees/presentation/employee_branch_assignments_screen.dart';
import '../features/employees/presentation/employee_management_hub_screen.dart';
import '../features/employees/presentation/employee_permissions_screen.dart';
import '../features/employees/presentation/my_permissions_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/audit_log_screen.dart';
import '../features/settings/presentation/user_guide_screen.dart';
import '../features/shifts/presentation/end_shift_screen.dart';
import '../features/shifts/presentation/shifts_archive_screen.dart';
import '../features/branches/presentation/inventory_transfer_screen.dart';
import '../features/branches/presentation/inventory_management_screen.dart';
import '../features/branches/presentation/branches_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final identityReady = ref.watch(sessionIdentityReadyProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isAuthenticated = authState.value != null && !authState.hasError;
      final isStartupRoute = state.uri.path == '/';
      if (!isAuthenticated && !isStartupRoute) return '/';
      if (isAuthenticated && isStartupRoute && identityReady) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const StartupScreen()),
      GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen()),
      GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: SettingsScreen())),
      GoRoute(
          path: '/user_guide',
          builder: (context, state) => const UserGuideScreen()),
      GoRoute(
          path: '/upgrade',
          builder: (context, state) => const UpgradeAccountScreen()),
      GoRoute(
          path: '/paywall',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: PaywallScreen())),
      GoRoute(
          path: '/expenses',
          builder: (context, state) => const _RouteAccess(
              permission: 'can_manage_expenses', child: ExpensesScreen())),
      GoRoute(
          path: '/suppliers',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: SuppliersScreen())),
      GoRoute(
          path: '/categories',
          builder: (context, state) => const _RouteAccess(
              permission: 'can_manage_products', child: CategoriesScreen())),
      GoRoute(
          path: '/inventory_logs',
          builder: (context, state) => const _RouteAccess(
              permission: 'can_manage_inventory',
              child: InventoryManagementScreen())),
      GoRoute(
          path: '/inventory_history',
          builder: (context, state) => const _RouteAccess(
              permission: 'can_manage_inventory', child: InventoryLogsScreen())),
      GoRoute(
          path: '/inventory_transfer',
          builder: (context, state) => const _RouteAccess(
              ownerOnly: true, child: InventoryTransferScreen())),
      GoRoute(
          path: '/branches',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: BranchesScreen())),
      GoRoute(
          path: '/employees',
          builder: (context, state) => const _RouteAccess(
              ownerOnly: true, child: EmployeeManagementHubScreen())),
      GoRoute(
          path: '/employees/manage',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: EmployeesScreen())),
      GoRoute(
          path: '/employee_branches',
          builder: (context, state) => const _RouteAccess(
              ownerOnly: true, child: EmployeeBranchAssignmentsScreen())),
      GoRoute(
          path: '/employee_permissions',
          builder: (context, state) => const _RouteAccess(
              ownerOnly: true, child: EmployeePermissionsScreen())),
      GoRoute(
          path: '/my_permissions',
          builder: (context, state) => const _RouteAccess(
              permission: 'my_permissions', child: MyPermissionsScreen())),
      GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: ProfileScreen())),
      GoRoute(
          path: '/subscription',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: PaywallScreen())),
      GoRoute(
          path: '/backup_security',
          builder: (context, state) => const _RouteAccess(
              ownerOnly: true, child: BackupSecurityScreen())),
      GoRoute(
          path: '/printer_settings',
          builder: (context, state) => const PrinterSettingsScreen()),
      GoRoute(
          path: '/store_branding',
          builder: (context, state) => const _RouteAccess(
              ownerOnly: true, child: StoreBrandingScreen())),
      GoRoute(
          path: '/end_shift',
          builder: (context, state) => const _RouteAccess(
              permission: 'can_close_shift', child: EndShiftScreen())),
      GoRoute(
          path: '/my_shifts',
          builder: (context, state) => const _RouteAccess(
              permission: 'my_shifts', child: ShiftsArchiveScreen())),
      GoRoute(
          path: '/shifts_archive',
          builder: (context, state) => const _RouteAccess(
              permission: 'can_view_shift_archive',
              child: ShiftsArchiveScreen())),
      GoRoute(
          path: '/raw_materials',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: RawMaterialsScreen())),
      GoRoute(
          path: '/audit_log',
          builder: (context, state) =>
              const _RouteAccess(ownerOnly: true, child: AuditLogScreen())),
    ],
  );
});

class _RouteAccess extends ConsumerWidget {
  final Widget child;
  final bool ownerOnly;
  final String? permission;

  const _RouteAccess({
    required this.child,
    this.ownerOnly = false,
    this.permission,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserState = ref.watch(appUserProvider);
    final policy = ref.watch(accessPolicyProvider);
    final identityReady = ref.watch(sessionIdentityReadyProvider);
    if (appUserState.isLoading || !identityReady || !policy.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (ownerOnly && !policy.isOwnerLike) return const DashboardScreen();
    if (permission != null && !policy.allowsRoutePermission(permission!)) {
      return const DashboardScreen();
    }
    return child;
  }
}

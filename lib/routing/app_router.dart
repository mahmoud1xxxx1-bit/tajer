import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/presentation/startup_screen.dart';
import '../features/authentication/presentation/upgrade_account_screen.dart';
import '../features/authentication/presentation/email_auth_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/subscriptions/presentation/paywall_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/backup_security_screen.dart';
import '../features/settings/presentation/printer_settings_screen.dart';
import '../features/expenses/presentation/expenses_screen.dart';
import '../features/suppliers/presentation/suppliers_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/inventory_log/presentation/inventory_logs_screen.dart';
import '../features/employees/presentation/employees_screen.dart';
import '../features/subscription/presentation/subscription_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final isStartupRoute = state.uri.path == '/';

      if (!isAuthenticated && !isStartupRoute) {
        return '/';
      }

      if (isAuthenticated && isStartupRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/upgrade',
        builder: (context, state) => const UpgradeAccountScreen(),
      ),
      GoRoute(
        path: '/email_auth',
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/inventory_logs',
        builder: (context, state) => const InventoryLogsScreen(),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const EmployeesScreen(),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/backup_security',
        builder: (context, state) => const BackupSecurityScreen(),
      ),
      GoRoute(
        path: '/printer_settings',
        builder: (context, state) => const PrinterSettingsScreen(),
      ),
    ],
  );
});

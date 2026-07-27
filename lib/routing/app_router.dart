import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/presentation/startup_screen.dart';
import '../features/authentication/presentation/upgrade_account_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/subscriptions/presentation/paywall_screen.dart';
import '../features/admin/presentation/admin_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

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
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
    ],
  );
});

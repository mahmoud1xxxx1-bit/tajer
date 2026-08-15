import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/authentication/data/auth_repository.dart';
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
import '../features/subscription/presentation/subscription_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/audit_log_screen.dart';
import '../features/settings/presentation/user_guide_screen.dart';
import '../features/shifts/presentation/end_shift_screen.dart';
import '../features/shifts/presentation/shifts_archive_screen.dart';
import '../features/accounting_notebook/presentation/notebook_home_screen.dart';
import '../features/accounting_notebook/presentation/income_expense_screen.dart';
import '../features/accounting_notebook/presentation/debt_screen.dart';
import '../features/accounting_notebook/presentation/notebook_accounts_screen.dart';
import '../features/accounting_notebook/presentation/notebook_people_screen.dart';
import '../features/accounting_notebook/presentation/notebook_reports_screen.dart';
import '../features/accounting_notebook/presentation/notebook_books_screen.dart';
import '../features/accounting_notebook/presentation/notebook_categories_screen.dart';
import '../features/accounting_notebook/presentation/notebook_transactions_screen.dart';


final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return null; // Wait for auth to resolve before redirecting
      final isAuthenticated = authState.value != null && !authState.hasError;
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
        path: '/user_guide',
        builder: (context, state) => const UserGuideScreen(),
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
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
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
      GoRoute(
        path: '/store_branding',
        builder: (context, state) => const StoreBrandingScreen(),
      ),
      GoRoute(
        path: '/end_shift',
        builder: (context, state) => const EndShiftScreen(),
      ),
      GoRoute(
        path: '/shifts_archive',
        builder: (context, state) => const ShiftsArchiveScreen(),
      ),
      GoRoute(
        path: '/raw_materials',
        builder: (context, state) => const RawMaterialsScreen(),
      ),
      GoRoute(
        path: '/audit_log',
        builder: (context, state) => const AuditLogScreen(),
      ),
    
      GoRoute(
        path: '/notebook',
        builder: (context, state) => const NotebookHomeScreen(),
      ),
    
      GoRoute(
        path: '/notebook/income',
        builder: (context, state) => const IncomeExpenseScreen(isIncome: true),
      ),
      GoRoute(
        path: '/notebook/expense',
        builder: (context, state) => const IncomeExpenseScreen(isIncome: false),
      ),
      GoRoute(
        path: '/notebook/debt/me',
        builder: (context, state) => const DebtScreen(isOwedToMe: true),
      ),
      GoRoute(
        path: '/notebook/debt/owe',
        builder: (context, state) => const DebtScreen(isOwedToMe: false),
      ),
      GoRoute(
        path: '/notebook/accounts',
        builder: (context, state) => const NotebookAccountsScreen(),
      ),
      GoRoute(
        path: '/notebook/people',
        builder: (context, state) => const NotebookPeopleScreen(),
      ),
      GoRoute(
        path: '/notebook/reports',
        builder: (context, state) => const NotebookReportsScreen(),
      ),
      GoRoute(
        path: '/notebook/books',
        builder: (context, state) => const NotebookBooksScreen(),
      ),
      GoRoute(
        path: '/notebook/categories',
        builder: (context, state) => const NotebookCategoriesScreen(),
      ),
      GoRoute(
        path: '/notebook/transactions',
        builder: (context, state) => const NotebookTransactionsScreen(),
      ),

    ],
  );
});

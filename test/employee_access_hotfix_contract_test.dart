import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Employee access hotfix contract', () {
    test(
        'employee branch bootstrap does not default missing assignment to main',
        () {
      final auth = File('lib/features/authentication/data/auth_repository.dart')
          .readAsStringSync();
      final appUser = File('lib/features/authentication/domain/app_user.dart')
          .readAsStringSync();
      final branchContext =
          File('lib/features/branches/presentation/branch_context.dart')
              .readAsStringSync();

      expect(auth, contains('if (raw is! List) return const [];'));
      expect(auth, contains('return branches;'));
      expect(appUser, contains('return assignedBranchIds.contains(branchId);'));
      expect(branchContext, contains("if (allowed.isEmpty) return '';"));
    });

    test('employee branch list is filtered by assigned document ids', () {
      final source = File('lib/features/branches/data/branch_repository.dart')
          .readAsStringSync();

      expect(source, contains('allowedBranchIds'));
      expect(source, contains('FieldPath.documentId'));
      expect(source, contains('whereIn: allowedBranchIds'));
      expect(source, contains('employeeAllowedBranchIdsProvider'));
    });

    test('employee data streams are scoped to the active branch before read',
        () {
      final orders = File('lib/features/orders/data/branch_orders_stream.dart')
          .readAsStringSync();
      final shifts = File('lib/features/shifts/data/shift_repository.dart')
          .readAsStringSync();
      final expenses =
          File('lib/features/expenses/data/expense_repository.dart')
              .readAsStringSync();
      final customers =
          File('lib/features/customers/data/customer_repository.dart')
              .readAsStringSync();
      final debtPayments = File(
              'lib/features/customers/data/customer_debt_payment_repository.dart')
          .readAsStringSync();
      final inventoryLogs =
          File('lib/features/inventory_log/data/inventory_log_repository.dart')
              .readAsStringSync();

      expect(orders, contains("where('branchId', isEqualTo: branchId)"));
      expect(shifts, contains("where('branchId', isEqualTo: branchId)"));
      expect(expenses, contains("where('branchId', isEqualTo: branchId)"));
      expect(customers, contains("where('branchId', isEqualTo: branchId)"));
      expect(debtPayments, contains("where('branchId', isEqualTo: branchId)"));
      expect(inventoryLogs, contains("where('branchId', isEqualTo: scope)"));
    });

    test('owner-only and permissioned routes are guarded beyond navigation',
        () {
      final router = File('lib/routing/app_router.dart').readAsStringSync();
      final drawer =
          File('lib/core/widgets/app_drawer.dart').readAsStringSync();

      expect(router, contains('class _RouteAccess extends ConsumerWidget'));
      expect(router, contains("path: '/branches'"));
      expect(router, contains('ownerOnly: true, child: BranchesScreen'));
      expect(router,
          contains('ownerOnly: true, child: EmployeePermissionsScreen'));
      expect(router, contains("permission: 'can_view_shift_archive'"));
      expect(router, contains("permission: 'can_manage_inventory'"));
      expect(router, contains('accessPolicyProvider'));
      expect(router, contains('policy.allowsRoutePermission'));
      expect(drawer, contains('accessPolicyProvider'));
      expect(drawer, contains('policy.canManageBranches'));
      expect(drawer, contains('policy.canManageEmployees'));
    });

    test('add employee dialog uses clean single-source permission copy', () {
      final source =
          File('lib/features/employees/presentation/employees_screen.dart')
              .readAsStringSync();
      final start = source.indexOf('Employee permissions:');
      final end = source.indexOf('style: const TextStyle(fontFamily:', start);
      final visiblePermissionCopy = source.substring(start, end);

      expect(visiblePermissionCopy, contains('Employee permissions:'));
      expect(visiblePermissionCopy, contains('Advanced Permissions'));
      expect(visiblePermissionCopy,
          contains('\\u0635\\u0644\\u0627\\u062d\\u064a\\u0627\\u062a'));
      expect(visiblePermissionCopy, isNot(contains('Ã')));
    });
  });
}

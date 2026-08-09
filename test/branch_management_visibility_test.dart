import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branch management is routed and visible from primary navigation', () {
    final router = File('lib/routing/app_router.dart').readAsStringSync();
    final dashboard =
        File('lib/features/dashboard/presentation/dashboard_screen.dart')
            .readAsStringSync();
    final drawer = File('lib/core/widgets/app_drawer.dart').readAsStringSync();
    final settings =
        File('lib/features/settings/presentation/settings_screen.dart')
            .readAsStringSync();

    expect(router, contains("path: '/branches'"));
    expect(router, contains('BranchesScreen'));
    expect(dashboard, contains("context.push('/branches')"));
    expect(drawer, contains("context.push('/branches')"));
    expect(settings, contains("context.push('/branches')"));
    expect(settings, contains('Tajer 1.1.108'));
  });

  test('branches screen surfaces existing branch operations', () {
    final screen =
        File('lib/features/branches/presentation/branches_screen.dart')
            .readAsStringSync();
    final selector =
        File('lib/features/branches/presentation/active_branch_selector.dart')
            .readAsStringSync();

    expect(screen, contains("context.push('/inventory_transfer')"));
    expect(screen, contains("context.push('/employee_branches')"));
    expect(screen, contains("context.push('/inventory_logs')"));
    expect(screen, contains('Branch Management'));
    expect(screen, contains('Add branch'));
    expect(selector, contains('selectedBranchIdProvider'));
    expect(selector, contains('branchContextProvider.notifier'));
  });
}

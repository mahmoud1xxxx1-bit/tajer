import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advanced employee permissions update both documents atomically', () {
    final source = File(
      'lib/features/employees/data/employee_permission_repository.dart',
    ).readAsStringSync();

    expect(source, contains('runTransaction<void>'));
    expect(source, contains("collection('employees').doc(employeeId)"));
    expect(source, contains("collection('users').doc(employeeId)"));
    expect(source, contains("tx.update(employeeRef"));
    expect(source, contains("tx.update(rootEmployeeRef"));
    expect(source, contains("rootData['merchantId']?.toString() != merchantUid"));
    expect(source, contains('Unknown employee permission key'));
  });

  test('advanced permissions UI uses atomic repository', () {
    final source = File(
      'lib/features/employees/presentation/employee_permissions_screen.dart',
    ).readAsStringSync();

    expect(source, contains('employeePermissionRepositoryProvider'));
    expect(source, contains('.updatePermissions('));
    expect(source, isNot(contains('updateEmployeePermissions(')));
  });
}

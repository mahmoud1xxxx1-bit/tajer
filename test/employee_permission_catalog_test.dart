import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/employees/domain/employee_permission_catalog.dart';

void main() {
  group('Employee permission catalog', () {
    test('catalog has unique keys and covers every declared permission', () {
      final definitions = EmployeePermissionCatalog.definitions;
      final keys = definitions.map((permission) => permission.key).toList();

      expect(keys.toSet().length, keys.length);
      expect(keys.toSet(), EmployeePermissionKeys.all);
    });

    test('high-impact permissions are opt-in by default', () {
      final defaults = EmployeePermissionCatalog.leastPrivilegeDefaults;

      expect(defaults[EmployeePermissionKeys.manageInventory], isFalse);
      expect(defaults[EmployeePermissionKeys.viewCost], isFalse);
      expect(defaults[EmployeePermissionKeys.cancelOrders], isFalse);
      expect(defaults[EmployeePermissionKeys.sellOnCredit], isFalse);
      expect(defaults[EmployeePermissionKeys.manageExpenses], isFalse);
    });

    test('Firestore authorization references only known employee permission keys', () {
      final rules = File('firestore.rules').readAsStringSync();
      final matches = RegExp(r"hasPermission\([^,]+, '([^']+)'\)")
          .allMatches(rules)
          .map((match) => match.group(1)!)
          .toSet();

      expect(matches, isNotEmpty);
      for (final key in matches) {
        expect(
          EmployeePermissionCatalog.isKnown(key),
          isTrue,
          reason: 'Unknown permission key referenced by Firestore rules: $key',
        );
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/employees/domain/employee_permission_catalog.dart';
import 'package:tajer/features/employees/domain/employee_permission_presentation.dart';

void main() {
  group('Employee permission presentation catalog', () {
    test('every permission has exactly one bilingual presentation entry', () {
      final items = EmployeePermissionPresentationCatalog.items;
      final keys = items.map((item) => item.key).toList();

      expect(keys.toSet().length, keys.length);
      expect(keys.toSet(), EmployeePermissionKeys.all);

      for (final item in items) {
        expect(item.titleAr.trim(), isNotEmpty);
        expect(item.titleEn.trim(), isNotEmpty);
        expect(item.descriptionAr.trim(), isNotEmpty);
        expect(item.descriptionEn.trim(), isNotEmpty);
      }
    });

    test('permissions are split into meaningful management groups', () {
      for (final group in EmployeePermissionGroup.values) {
        expect(
          EmployeePermissionPresentationCatalog.forGroup(group),
          isNotEmpty,
          reason: 'Permission group $group must not be empty',
        );
      }
    });
  });
}

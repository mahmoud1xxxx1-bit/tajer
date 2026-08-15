import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';

void main() {
  group('Accounting Notebook employee permission contract', () {
    test('merchant always has notebook access', () {
      final merchant = AppUser(
        id: 'merchant1',
        role: 'merchant',
        isAnonymous: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(merchant.hasPermission('can_access_accounting_notebook'), isTrue);
    });

    test('employee without notebook permission is denied', () {
      final employee = AppUser(
        id: 'employee1',
        role: 'employee',
        merchantId: 'merchant1',
        isAnonymous: false,
        createdAt: DateTime(2026, 1, 1),
        permissions: const {
          'can_create_orders': true,
          'can_access_accounting_notebook': false,
        },
      );

      expect(employee.hasPermission('can_access_accounting_notebook'), isFalse);
    });

    test('employee with notebook permission is allowed', () {
      final employee = AppUser(
        id: 'employee1',
        role: 'employee',
        merchantId: 'merchant1',
        isAnonymous: false,
        createdAt: DateTime(2026, 1, 1),
        permissions: const {
          'can_access_accounting_notebook': true,
        },
      );

      expect(employee.hasPermission('can_access_accounting_notebook'), isTrue);
    });
  });
}

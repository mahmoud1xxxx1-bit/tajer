import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';

AppUser _user({
  required String role,
  List<String> assignedBranchIds = const <String>[],
}) {
  return AppUser(
    id: 'user-1',
    createdAt: DateTime(2026, 8, 8),
    isAnonymous: false,
    role: role,
    assignedBranchIds: assignedBranchIds,
  );
}

void main() {
  group('Employee branch access policy', () {
    test('merchant can access every branch', () {
      final user = _user(role: 'merchant');
      expect(user.canAccessBranch('main'), isTrue);
      expect(user.canAccessBranch('branch-2'), isTrue);
      expect(user.canAccessBranch('branch-99'), isTrue);
    });

    test('admin can access every branch', () {
      final user = _user(role: 'admin');
      expect(user.canAccessBranch('main'), isTrue);
      expect(user.canAccessBranch('branch-2'), isTrue);
    });

    test('legacy employee without assignments is main-only', () {
      final user = _user(role: 'employee');
      expect(user.canAccessBranch('main'), isTrue);
      expect(user.canAccessBranch('branch-2'), isFalse);
    });

    test('employee can access only explicitly assigned branches', () {
      final user = _user(
        role: 'employee',
        assignedBranchIds: const <String>['branch-2', 'branch-4'],
      );
      expect(user.canAccessBranch('main'), isFalse);
      expect(user.canAccessBranch('branch-2'), isTrue);
      expect(user.canAccessBranch('branch-4'), isTrue);
      expect(user.canAccessBranch('branch-3'), isFalse);
    });

    test('feature permission does not imply branch permission', () {
      final user = AppUser(
        id: 'employee-1',
        createdAt: DateTime(2026, 8, 8),
        isAnonymous: false,
        role: 'employee',
        permissions: const <String, dynamic>{'can_create_orders': true},
        assignedBranchIds: const <String>['branch-2'],
      );
      expect(user.hasPermission('can_create_orders'), isTrue);
      expect(user.canAccessBranch('branch-2'), isTrue);
      expect(user.canAccessBranch('branch-3'), isFalse);
    });
  });
}

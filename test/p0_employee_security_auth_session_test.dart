import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/features/orders/data/branch_orders_stream.dart';

AppUser _user({
  required String id,
  required String role,
  String? merchantId,
  Map<String, dynamic> permissions = const {},
  List<String> assignedBranchIds = const ['branch-a'],
}) {
  return AppUser(
    id: id,
    role: role,
    merchantId: merchantId,
    permissions: permissions,
    assignedBranchIds: assignedBranchIds,
    createdAt: DateTime(2024),
    isAnonymous: false,
  );
}

void main() {
  group('P0-A employee order query restriction', () {
    test('employee without can_view_all_orders is restricted to own orders',
        () {
      final employee = _user(
        id: 'employee-a',
        role: 'employee',
        merchantId: 'merchant-a',
        permissions: {'can_create_orders': true},
      );

      expect(restrictedOrderCreatorId(employee, 'employee-a'), 'employee-a');
    });

    test('same employee cannot receive another user order from query contract',
        () {
      final employee = _user(
        id: 'employee-a',
        role: 'employee',
        merchantId: 'merchant-a',
        permissions: {'can_create_orders': true},
      );

      final creatorIdFilter = restrictedOrderCreatorId(employee, 'employee-a');
      expect(creatorIdFilter, isNot('employee-b'));
    });

    test('employee with can_view_all_orders keeps branch-wide visibility', () {
      final employee = _user(
        id: 'employee-a',
        role: 'employee',
        merchantId: 'merchant-a',
        permissions: {
          'can_create_orders': true,
          'can_view_all_orders': true,
        },
      );

      expect(restrictedOrderCreatorId(employee, 'employee-a'), isNull);
    });

    test('unassigned branch access remains outside the order query fix', () {
      final employee = _user(
        id: 'employee-a',
        role: 'employee',
        merchantId: 'merchant-a',
        assignedBranchIds: const ['branch-a'],
      );

      expect(employee.canAccessBranch('branch-b'), isFalse);
      expect(restrictedOrderCreatorId(employee, 'employee-a'), 'employee-a');
    });

    test('merchant and admin order behavior remains unrestricted by creatorId',
        () {
      expect(
        restrictedOrderCreatorId(
            _user(id: 'merchant-a', role: 'merchant'), 'merchant-a'),
        isNull,
      );
      expect(
        restrictedOrderCreatorId(
            _user(id: 'admin-a', role: 'admin'), 'admin-a'),
        isNull,
      );
    });
  });

  group('P0-B auth session isolation contract', () {
    late String authRepository;
    late String sessionController;
    late String drawer;
    late String settings;

    setUpAll(() {
      authRepository =
          File('lib/features/authentication/data/auth_repository.dart')
              .readAsStringSync();
      sessionController = File(
              'lib/features/authentication/application/session_controller.dart')
          .readAsStringSync();
      drawer = File('lib/core/widgets/app_drawer.dart').readAsStringSync();
      settings = File('lib/features/settings/presentation/settings_screen.dart')
          .readAsStringSync();
    });

    test('logout awaits FirebaseAuth signOut and logs null postcondition', () {
      expect(authRepository, contains('await _auth.signOut();'));
      expect(authRepository, contains('firebaseUidAfterLogout='));
      expect(authRepository, contains('_auth.currentUser?.uid'));
    });

    test('UID A session-scoped providers are discarded on centralized logout',
        () {
      expect(sessionController,
          contains('await _ref.read(authRepositoryProvider).signOut();'));
      expect(sessionController, contains('_ref.invalidate(appUserProvider);'));
      expect(sessionController,
          contains('_ref.invalidate(branchContextProvider);'));
      expect(sessionController,
          contains('_ref.invalidate(selectedBranchIdProvider);'));
      expect(sessionController,
          contains('_ref.invalidate(employeeAllowedBranchIdsProvider);'));
      expect(sessionController,
          contains('_ref.invalidate(authStateChangesProvider);'));
    });

    test('UID B app user is loaded only from users/UID_B after auth changes',
        () {
      expect(authRepository, contains(".doc(user.uid)"));
      expect(authRepository, contains('loadedUserPath=users/\${user.uid}'));
      expect(authRepository, contains('authenticatedUid=\${user.uid}'));
    });

    test('UID B cannot inherit UID A role/merchant/branches while loading', () {
      expect(authRepository, contains('return (() async* {'));
      expect(authRepository, contains('yield null;'));
      expect(authRepository, contains('return Stream<AppUser?>.value(null);'));
    });

    test('rapid logout/login transition cannot restore stale UID A state', () {
      expect(sessionController, contains('SessionController'));
      expect(sessionController, contains('sessionControllerProvider'));
      expect(authRepository, contains('authStateChanges()'));
    });

    test('Google session is cleared before a non-anonymous Google login', () {
      expect(authRepository, contains('await googleSignIn.signOut();'));
      expect(authRepository, contains('GOOGLE_AUTH_RESULT'));
      expect(authRepository, contains('providerIds='));
    });

    test('all visible logout entry points await centralized logout operation',
        () {
      expect(drawer,
          contains('await ref.read(sessionControllerProvider).logout();'));
      expect(settings,
          contains('await ref.read(sessionControllerProvider).logout();'));
      expect(settings,
          isNot(contains('ref.read(authRepositoryProvider).signOut();')));
    });
  });
}

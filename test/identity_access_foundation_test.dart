import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/authentication/application/access_policy.dart';
import 'package:tajer/features/authentication/application/session_identity.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';

AppUser _appUser({
  required String id,
  required String role,
  String? merchantId,
  Map<String, dynamic> permissions = const {},
  List<String> assignedBranchIds = const [],
}) {
  return AppUser(
    id: id,
    role: role,
    merchantId: merchantId,
    permissions: permissions,
    assignedBranchIds: assignedBranchIds,
    createdAt: DateTime(2026),
    isAnonymous: false,
  );
}

SessionIdentity _identity({
  required AppUser user,
  required String effectiveMerchantId,
  required String activeBranchId,
}) {
  return SessionIdentity(
    uid: user.id,
    role: user.role,
    effectiveMerchantId: effectiveMerchantId,
    assignedBranchIds: user.assignedBranchIds,
    permissions: user.permissions,
    activeBranchId: activeBranchId,
    isOwnerLike:
        user.role == 'merchant' || user.role == 'admin' || user.role == 'owner',
    appUser: user,
  );
}

void main() {
  group('identity and access foundation', () {
    test('owner identity keeps owner workspace and administrative access', () {
      final user = _appUser(id: 'owner-uid', role: 'merchant');
      final identity = _identity(
        user: user,
        effectiveMerchantId: 'owner-uid',
        activeBranchId: 'main',
      );
      final policy = AccessPolicy(identity);

      expect(identity.uid, 'owner-uid');
      expect(identity.effectiveMerchantId, 'owner-uid');
      expect(policy.isOwnerLike, isTrue);
      expect(policy.canManageBranches, isTrue);
      expect(policy.canManageEmployees, isTrue);
      expect(policy.canViewAuditLog, isTrue);
      expect(policy.canCreateOrders, isTrue);
    });

    test('restricted employee identity is branch and permission scoped', () {
      final user = _appUser(
        id: 'employee-a',
        role: 'employee',
        merchantId: 'merchant-a',
        permissions: {
          'can_create_orders': true,
        },
        assignedBranchIds: const ['branch-a'],
      );
      final identity = _identity(
        user: user,
        effectiveMerchantId: 'merchant-a',
        activeBranchId: 'branch-a',
      );
      final policy = AccessPolicy(identity);

      expect(identity.uid, 'employee-a');
      expect(identity.effectiveMerchantId, 'merchant-a');
      expect(policy.isOwnerLike, isFalse);
      expect(policy.hasAssignedBranch, isTrue);
      expect(policy.canCreateOrders, isTrue);
      expect(policy.canViewOwnOrders, isTrue);
      expect(policy.canViewAllOrders, isFalse);
      expect(policy.canManageBranches, isFalse);
      expect(policy.canManageEmployees, isFalse);
      expect(policy.canViewAuditLog, isFalse);
      expect(policy.canViewCosts, isFalse);
    });

    test('employee cannot operate outside assigned active branch', () {
      final user = _appUser(
        id: 'employee-a',
        role: 'employee',
        merchantId: 'merchant-a',
        permissions: {
          'can_create_orders': true,
          'can_view_reports': true,
        },
        assignedBranchIds: const ['branch-a'],
      );
      final identity = _identity(
        user: user,
        effectiveMerchantId: 'merchant-a',
        activeBranchId: 'branch-b',
      );
      final policy = AccessPolicy(identity);

      expect(policy.hasAssignedBranch, isFalse);
      expect(policy.canCreateOrders, isFalse);
      expect(policy.canViewReports, isFalse);
      expect(policy.canCloseShift, isFalse);
    });

    test('grant and revoke explicit permission changes feature availability',
        () {
      final base = _appUser(
        id: 'employee-a',
        role: 'employee',
        merchantId: 'merchant-a',
        assignedBranchIds: const ['branch-a'],
      );
      final revoked = AccessPolicy(_identity(
        user: base,
        effectiveMerchantId: 'merchant-a',
        activeBranchId: 'branch-a',
      ));
      final granted = AccessPolicy(_identity(
        user: base.copyWith(permissions: {'can_manage_expenses': true}),
        effectiveMerchantId: 'merchant-a',
        activeBranchId: 'branch-a',
      ));

      expect(revoked.canManageExpenses, isFalse);
      expect(granted.canManageExpenses, isTrue);
    });
  });

  group('identity architecture source contracts', () {
    late String drawer;
    late String router;
    late String dashboard;
    late Map<String, dynamic> indexes;
    late String firebaseJson;

    setUpAll(() {
      drawer = File('lib/core/widgets/app_drawer.dart').readAsStringSync();
      router = File('lib/routing/app_router.dart').readAsStringSync();
      dashboard =
          File('lib/features/dashboard/presentation/dashboard_screen.dart')
              .readAsStringSync();
      indexes = jsonDecode(File('firestore.indexes.json').readAsStringSync())
          as Map<String, dynamic>;
      firebaseJson = File('firebase.json').readAsStringSync();
    });

    test('employee drawer is generated from AccessPolicy', () {
      expect(drawer, contains('accessPolicyProvider'));
      expect(drawer, contains('policy.canManageBranches'));
      expect(drawer, contains('policy.canManageEmployees'));
      expect(drawer, contains('policy.canAccessMerchantSettings'));
      expect(drawer, isNot(contains("if (appUser?.role != 'employee')")));
    });

    test('direct forbidden routes are blocked by AccessPolicy', () {
      expect(router, contains('accessPolicyProvider'));
      expect(router, contains('policy.allowsRoutePermission'));
      expect(router, contains('policy.isOwnerLike'));
      expect(router, contains('sessionIdentityReadyProvider'));
    });

    test('dashboard waits for session identity and uses access policy', () {
      expect(dashboard, contains('sessionIdentityReadyProvider'));
      expect(dashboard, contains('accessPolicyProvider'));
      expect(dashboard, contains('policy.canCreateOrders'));
      expect(dashboard, contains('policy.canManageCustomers'));
      expect(dashboard, contains('policy.canViewReports'));
    });

    test('store identity completion banner is owner policy gated', () {
      expect(dashboard, contains('completeStoreBrandingAlert'));
      expect(dashboard, contains('policy.canAccessBranding &&'));
      expect(dashboard,
          contains('(storeProfile?.storeName.isEmpty ?? true)'));
    });

    test('audit and changed compound query indexes are declared', () {
      expect(firebaseJson, contains('"indexes": "firestore.indexes.json"'));
      final list = indexes['indexes'] as List<dynamic>;

      bool hasIndex(String collectionGroup, List<String> fields) {
        return list.any((raw) {
          final index = raw as Map<String, dynamic>;
          if (index['collectionGroup'] != collectionGroup) return false;
          final actual = (index['fields'] as List<dynamic>)
              .map((field) => (field as Map<String, dynamic>)['fieldPath'])
              .toList();
          return actual.join('|') == fields.join('|');
        });
      }

      expect(hasIndex('inventory_logs', ['branchId', 'date']), isTrue);
      expect(
          hasIndex('orders', ['merchantId', 'branchId', 'creatorId']), isTrue);
      expect(hasIndex('expenses', ['branchId', 'date']), isTrue);
      expect(
          hasIndex('shifts', ['merchantId', 'branchId', 'startTime']), isTrue);
    });
  });
}

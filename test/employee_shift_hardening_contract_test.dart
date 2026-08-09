import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('employee shift hardening source contracts', () {
    late String rules;
    late String shiftRepository;
    late String accessPolicy;
    late String router;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
      shiftRepository = File('lib/features/shifts/data/shift_repository.dart')
          .readAsStringSync();
      accessPolicy =
          File('lib/features/authentication/application/access_policy.dart')
              .readAsStringSync();
      router = File('lib/routing/app_router.dart').readAsStringSync();
    });

    test('branch runtime no longer falls through to owner-only merchant rules',
        () {
      expect(rules, contains('match /branch_runtime/{branchId}'));
      expect(rules, contains('hasBranchAccess(merchantId, branchId)'));
      expect(rules, contains("hasPermission(merchantId, 'can_create_orders')"));
      expect(
        rules,
        contains("request.resource.data.get('branchId', branchId) == branchId"),
      );
      expect(rules, contains('allow delete: if isOwner(merchantId)'));
    });

    test('shift create requires assigned branch and create-orders permission',
        () {
      expect(
        rules,
        contains(
          "allow create: if hasPermission(request.resource.data.get('merchantId', ''), 'can_create_orders')",
        ),
      );
      expect(
        rules,
        contains(
          "hasDataBranchAccess(request.resource.data.get('merchantId', ''), request.resource.data)",
        ),
      );
    });

    test('employee default shift history is own-history only in repository',
        () {
      expect(shiftRepository, contains('canViewOwnShiftHistory'));
      expect(shiftRepository, contains('shift.employeeId == appUser.id'));
      expect(shiftRepository, contains('policy.canViewShiftArchive'));
    });

    test('reports permission is not the shift archive route permission', () {
      expect(accessPolicy, contains("case 'can_view_shift_archive':"));
      expect(accessPolicy, contains('canViewShiftArchive ||'));
      expect(router, contains("permission: 'can_view_shift_archive'"));
      expect(
        router,
        isNot(contains(
            "permission: 'can_view_reports', child: ShiftsArchiveScreen")),
      );
    });
  });
}

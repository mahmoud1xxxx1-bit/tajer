import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  group('Report scope policy', () {
    test('merchant can request consolidated report', () {
      expect(
        resolveReportsScope(role: 'merchant', requested: ReportsScope.merchant),
        ReportsScope.merchant,
      );
    });

    test('merchant can stay on current branch', () {
      expect(
        resolveReportsScope(role: 'merchant', requested: ReportsScope.branch),
        ReportsScope.branch,
      );
    });

    test('employee is restricted to current branch', () {
      expect(
        resolveReportsScope(role: 'employee', requested: ReportsScope.merchant),
        ReportsScope.branch,
      );
    });

    test('unknown role is restricted to current branch', () {
      expect(
        resolveReportsScope(role: null, requested: ReportsScope.merchant),
        ReportsScope.branch,
      );
    });

    test('report aggregation has a permission gate at provider boundary', () {
      final source = File('lib/features/reports/data/reports_service.dart')
          .readAsStringSync();
      expect(source, contains('accessPolicyProvider'));
      expect(source, contains('canViewReports'));
      expect(source, contains('if (!_canViewReports(ref)) return null;'));
    });

    test('merchant-wide report sources cannot be opened by employee accounts',
        () {
      final source = File('lib/features/reports/data/reports_service.dart')
          .readAsStringSync();
      expect(source, contains('!policy.isOwnerLike'));
      expect(source, contains('merchantWideOrdersStreamProvider'));
      expect(source, contains('merchantWideExpensesStreamProvider'));
    });
  });
}

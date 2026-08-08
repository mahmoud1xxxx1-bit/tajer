import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-branch Firestore security contract', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    test('customer debt provenance is explicitly permissioned', () {
      expect(rules, contains("match /customer_debt_payments/{paymentId}"));
      expect(
        rules,
        contains("allow create: if hasPermission(merchantId, 'can_receive_payments');"),
      );
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('customer financial snapshots cannot grant arbitrary profile edits', () {
      expect(rules, contains('isCustomerOrderAccountingUpdate'));
      expect(rules, contains('isCustomerDebtAccountingUpdate'));
      expect(
        rules,
        contains("request.resource.data.diff(resource.data).affectedKeys().hasOnly(["),
      );
      expect(rules, contains("'totalDebt'"));
      expect(rules, contains("'totalPurchases'"));
      expect(rules, contains("'orderCount'"));
    });

    test('inventory audit log is append-only for cashiers', () {
      expect(rules, contains('match /inventory_logs/{logId}'));
      expect(
        rules,
        contains("allow create: if hasPermission(merchantId, 'can_manage_inventory') || hasPermission(merchantId, 'can_create_orders');"),
      );
      expect(
        rules,
        contains("allow update, delete: if hasPermission(merchantId, 'can_manage_inventory');"),
      );
    });

    test('branch configuration is owner controlled', () {
      expect(rules, contains('match /branches/{branchId}'));
      expect(
        rules,
        contains("branchId == 'main' && request.resource.data.get('isMain', false) == true"),
      );
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('branch inventory is explicitly permissioned for POS and inventory roles', () {
      expect(rules, contains('match /branch_inventory/{inventoryId}'));
      expect(
        rules,
        contains("hasPermission(merchantId, 'can_manage_inventory') || hasPermission(merchantId, 'can_create_orders')"),
      );
      expect(rules, contains('allow delete: if isOwner(merchantId);'));
    });

    test('unknown merchant subcollection writes are owner only', () {
      expect(rules, contains('match /{subcollection=**}'));
      expect(rules, contains('allow write: if isOwner(merchantId);'));
    });
  });
}

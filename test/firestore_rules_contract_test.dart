import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-branch Firestore security contract', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    test('employee branch authorization defaults legacy users to main', () {
      expect(rules, contains('function hasBranchAccess(merchantId, branchId)'));
      expect(rules, contains("data.get('assignedBranchIds', ['main']).hasAny([branchId])"));
    });

    test('orders require both permission and branch authorization', () {
      expect(rules, contains('match /orders/{orderId}'));
      expect(rules, contains("hasPermission(request.resource.data.get('merchantId', ''), 'can_create_orders')"));
      expect(rules, contains("hasDataBranchAccess(request.resource.data.get('merchantId', ''), request.resource.data)"));
    });

    test('customer debt provenance is explicitly permissioned and branch scoped', () {
      expect(rules, contains('match /customer_debt_payments/{paymentId}'));
      expect(rules, contains("hasPermission(merchantId, 'can_receive_payments') && hasDataBranchAccess(merchantId, request.resource.data)"));
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('customer financial snapshots cannot grant arbitrary profile edits', () {
      expect(rules, contains('isCustomerOrderAccountingUpdate'));
      expect(rules, contains('isCustomerDebtAccountingUpdate'));
      expect(rules, contains('affectedKeys().hasOnly'));
      expect(rules, contains("'totalDebt'"));
      expect(rules, contains("'totalPurchases'"));
      expect(rules, contains("'orderCount'"));
    });

    test('inventory audit log is branch scoped', () {
      expect(rules, contains('match /inventory_logs/{logId}'));
      expect(rules, contains('hasDataBranchAccess(merchantId, request.resource.data)'));
      expect(rules, contains("hasPermission(merchantId, 'can_manage_inventory') || hasPermission(merchantId, 'can_create_orders')"));
    });

    test('inventory transfer requires access to source and destination', () {
      expect(rules, contains('match /inventory_transfers/{transferId}'));
      expect(rules, contains("hasBranchAccess(merchantId, request.resource.data.get('fromBranchId', 'main'))"));
      expect(rules, contains("hasBranchAccess(merchantId, request.resource.data.get('toBranchId', 'main'))"));
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('branch configuration is owner controlled while reads are scoped', () {
      expect(rules, contains('match /branches/{branchId}'));
      expect(rules, contains('allow read: if hasAccess(merchantId) && hasBranchAccess(merchantId, branchId);'));
      expect(rules, contains("branchId == 'main' && request.resource.data.get('isMain', false) == true"));
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('branch inventory is explicitly permissioned and branch scoped', () {
      expect(rules, contains('match /branch_inventory/{inventoryId}'));
      expect(rules, contains('hasDataBranchAccess(merchantId, request.resource.data)'));
      expect(rules, contains("hasPermission(merchantId, 'can_manage_inventory') || hasPermission(merchantId, 'can_create_orders')"));
      expect(rules, contains('allow delete: if resource == null || isOwner(merchantId);'));
    });

    test('unknown merchant subcollection writes are owner only', () {
      expect(rules, contains('match /{subcollection=**}'));
      expect(rules, contains('allow write: if isOwner(merchantId);'));
    });
  });
}

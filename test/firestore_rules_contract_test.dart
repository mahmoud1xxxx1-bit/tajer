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

    test('employees cannot self-escalate permissions or branch assignments', () {
      expect(rules, contains('function isSafeSelfUserUpdate(userId)'));
      expect(rules, contains("'permissions', 'assignedBranchIds'"));
      expect(rules, contains("'plan', 'role', 'merchantId'"));
      expect(rules, contains('allow update: if isSafeSelfUserUpdate(userId) ||'));
      expect(rules, contains("isOwner(resource.data.get('merchantId', ''))"));
    });

    test('employee root documents can only be created by self or merchant owner', () {
      expect(rules, contains('request.auth.uid == userId ||'));
      expect(rules, contains("isOwner(request.resource.data.get('merchantId', ''))"));
    });

    test('orders require both permission and branch authorization', () {
      expect(rules, contains('match /orders/{orderId}'));
      expect(rules, contains("hasPermission(request.resource.data.get('merchantId', ''), 'can_create_orders')"));
      expect(rules, contains("hasDataBranchAccess(request.resource.data.get('merchantId', ''), request.resource.data)"));
    });

    test('order visibility respects view-all permission or creator ownership', () {
      expect(rules, contains('function canReadOrder(merchantId, data)'));
      expect(rules, contains("hasPermission(merchantId, 'can_view_all_orders')"));
      expect(rules, contains("data.get('creatorId', '') == request.auth.uid"));
      expect(rules, contains("allow read: if resource != null && canReadOrder(resource.data.get('merchantId', ''), resource.data);"));
    });

    test('order cancellation requires dedicated cancellation permission', () {
      expect(rules, contains('function isOrderCancellation(merchantId)'));
      expect(rules, contains("request.resource.data.get('status', '') == 'cancelled'"));
      expect(rules, contains("hasPermission(merchantId, 'can_cancel_orders')"));
      expect(rules, contains("request.resource.data.get('branchId', 'main') == resource.data.get('branchId', 'main')"));
    });

    test('product cost is isolated from normal product documents', () {
      expect(rules, contains('match /products/{productId}'));
      expect(rules, contains("resource.data.get('costPrice', null) == null"));
      expect(rules, contains("hasPermission(resource.data.get('merchantId', ''), 'can_view_cost')"));
      expect(rules, contains("request.resource.data.get('costPrice', null) == null"));
    });

    test('protected product cost collection requires explicit permissions', () {
      expect(rules, contains('match /product_costs/{productId}'));
      expect(rules, contains("allow read: if hasPermission(merchantId, 'can_view_cost');"));
      expect(rules, contains("allow create, update, delete: if hasPermission(merchantId, 'can_manage_products') &&"));
      expect(rules, contains("hasPermission(merchantId, 'can_view_cost');"));
    });

    test('historical order cost snapshots require reports, cost and branch access', () {
      expect(rules, contains('match /order_cost_snapshots/{orderId}'));
      expect(rules, contains("hasPermission(merchantId, 'can_view_cost')"));
      expect(rules, contains("hasPermission(merchantId, 'can_view_reports')"));
      expect(rules, contains('hasDataBranchAccess(merchantId, resource.data)'));
      expect(rules, contains('allow create, update, delete: if isOwner(merchantId);'));
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

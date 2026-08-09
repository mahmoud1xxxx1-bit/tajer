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
      expect(
          rules,
          contains(
              "data.get('assignedBranchIds', ['main']).hasAny([branchId])"));
    });

    test('employees cannot self-escalate permissions or branch assignments',
        () {
      expect(rules, contains('function isSafeSelfUserUpdate(userId)'));
      expect(rules, contains("'permissions', 'assignedBranchIds'"));
      expect(rules, contains("'plan', 'role', 'merchantId'"));
      expect(
          rules, contains('allow update: if isSafeSelfUserUpdate(userId) ||'));
      expect(rules, contains("isOwner(resource.data.get('merchantId', ''))"));
    });

    test(
        'employee root documents can only be created by self or merchant owner',
        () {
      expect(rules, contains('request.auth.uid == userId ||'));
      expect(rules,
          contains("isOwner(request.resource.data.get('merchantId', ''))"));
    });

    test('orders require both permission and branch authorization', () {
      expect(rules, contains('match /orders/{orderId}'));
      expect(
          rules,
          contains(
              "hasPermission(request.resource.data.get('merchantId', ''), 'can_create_orders')"));
      expect(
          rules,
          contains(
              "hasDataBranchAccess(request.resource.data.get('merchantId', ''), request.resource.data)"));
    });

    test('order visibility respects view-all permission or creator ownership',
        () {
      expect(rules, contains('function canReadOrder(merchantId, data)'));
      expect(
          rules, contains("hasPermission(merchantId, 'can_view_all_orders')"));
      expect(rules, contains("data.get('creatorId', '') == request.auth.uid"));
      expect(
          rules,
          contains(
              "allow get: if (resource == null && isAuthenticated()) || canReadOrder(resource.data.get('merchantId', ''), resource.data);"));
      expect(
          rules,
          contains(
              "allow list: if resource != null && canReadOrder(resource.data.get('merchantId', ''), resource.data);"));
    });

    test('order cancellation requires dedicated cancellation permission', () {
      expect(rules, contains('function isOrderCancellation(merchantId)'));
      expect(rules,
          contains("request.resource.data.get('status', '') == 'cancelled'"));
      expect(rules, contains("hasPermission(merchantId, 'can_cancel_orders')"));
      expect(
          rules,
          contains(
              "request.resource.data.get('branchId', 'main') == resource.data.get('branchId', 'main')"));
    });

    test('order updates are constrained to status or payment accounting fields',
        () {
      expect(rules, contains('function isOrderStatusTransition(merchantId)'));
      expect(rules, contains('function isOrderAccountingUpdate(merchantId)'));
      expect(
          rules,
          contains(
              "affectedKeys().hasOnly(['status', 'statusTransition', 'updatedAt'])"));
      expect(rules,
          contains("affectedKeys().hasOnly(['paidAmount', 'updatedAt'])"));
      expect(
          rules,
          contains(
              "request.resource.data.get('creatorId', '') == resource.data.get('creatorId', '')"));
      expect(
          rules, contains("hasPermission(merchantId, 'can_receive_payments')"));
    });

    test('product cost is isolated from normal product documents', () {
      expect(rules, contains('match /products/{productId}'));
      expect(rules, contains("resource.data.get('costPrice', null) == null"));
      expect(
          rules,
          contains(
              "hasPermission(resource.data.get('merchantId', ''), 'can_view_cost')"));
      expect(rules, contains('function isProductMasterCreate()'));
      expect(rules, contains('function isProductMasterUpdate()'));
      expect(
          rules,
          contains(
              "!request.resource.data.diff(resource.data).affectedKeys().hasAny(['quantity', 'initialQuantity'])"));
    });

    test('raw material master stock fields cannot be directly rewritten', () {
      expect(rules, contains('function isRawMaterialCreate()'));
      expect(rules, contains('function isRawMaterialUpdate()'));
      expect(rules,
          contains("request.resource.data.get('initialQuantity', 0) == 0"));
      expect(
          rules,
          contains(
              "!request.resource.data.diff(resource.data).affectedKeys().hasAny(['quantity', 'initialQuantity'])"));
    });

    test('protected product cost collection requires explicit permissions', () {
      expect(rules, contains('match /product_costs/{productId}'));
      expect(
          rules,
          contains(
              "allow read: if hasPermission(merchantId, 'can_view_cost');"));
      expect(
          rules,
          contains(
              "allow create, update: if hasPermission(merchantId, 'can_manage_products') &&"));
      expect(
          rules,
          contains(
              "request.resource.data.get('merchantId', '') == merchantId"));
      expect(rules,
          contains("request.resource.data.get('productId', '') == productId"));
      expect(
          rules, contains("request.resource.data.get('costPrice', -1) >= 0"));
      expect(
          rules,
          contains(
              "allow delete: if hasPermission(merchantId, 'can_manage_products') &&"));
    });

    test(
        'historical order cost snapshots require reports, cost and branch access',
        () {
      expect(rules, contains('match /order_cost_snapshots/{orderId}'));
      expect(rules, contains("hasPermission(merchantId, 'can_view_cost')"));
      expect(rules, contains("hasPermission(merchantId, 'can_view_reports')"));
      expect(rules, contains('hasDataBranchAccess(merchantId, resource.data)'));
      expect(rules, contains('allow create, update, delete: if false;'));
    });

    test(
        'customer debt provenance is explicitly permissioned and branch scoped',
        () {
      expect(rules, contains('match /customer_debt_payments/{paymentId}'));
      expect(
          rules,
          contains(
              "hasPermission(merchantId, 'can_receive_payments') && hasDataBranchAccess(merchantId, request.resource.data)"));
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('customer financial snapshots cannot grant arbitrary profile edits',
        () {
      expect(rules, contains('isCustomerOrderAccountingUpdate'));
      expect(rules, contains('isCustomerDebtAccountingUpdate'));
      expect(rules, contains('affectedKeys().hasOnly'));
      expect(rules, contains("'totalDebt'"));
      expect(rules, contains("'totalPurchases'"));
      expect(rules, contains("'orderCount'"));
    });

    test('inventory audit log is branch scoped', () {
      expect(rules, contains('match /inventory_logs/{logId}'));
      expect(rules,
          contains('hasDataBranchAccess(merchantId, request.resource.data)'));
      expect(
          rules, contains("hasPermission(merchantId, 'can_manage_inventory')"));
      expect(
          rules,
          contains('isCheckoutInventoryLogCreate'));
      expect(
          rules,
          contains(
              "hasPermission(merchantId, 'can_cancel_orders')"));
    });

    test('inventory transfer requires access to source and destination', () {
      expect(rules, contains('match /inventory_transfers/{transferId}'));
      expect(
          rules,
          contains(
              "hasBranchAccess(merchantId, request.resource.data.get('fromBranchId', 'main'))"));
      expect(
          rules,
          contains(
              "hasBranchAccess(merchantId, request.resource.data.get('toBranchId', 'main'))"));
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('branch configuration is owner controlled while reads are scoped', () {
      expect(rules, contains('match /branches/{branchId}'));
      expect(
          rules,
          contains(
              'allow read: if hasAccess(merchantId) && hasBranchAccess(merchantId, branchId);'));
      expect(
          rules,
          contains(
              "branchId == 'main' && request.resource.data.get('isMain', false) == true"));
      expect(rules, contains('allow update, delete: if isOwner(merchantId);'));
    });

    test('branch inventory is explicitly permissioned and branch scoped', () {
      expect(rules, contains('match /branch_inventory/{inventoryId}'));
      expect(rules,
          contains('hasDataBranchAccess(merchantId, request.resource.data)'));
      expect(
          rules, contains("hasPermission(merchantId, 'can_manage_inventory')"));
      expect(
          rules,
          contains('isCheckoutInventoryUpdate'));
      expect(
          rules,
          contains('isCancellationInventoryUpdate'));
      expect(
          rules,
          contains(
              "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['id', 'quantity', 'initialQuantity', 'updatedAt'])"));
      expect(rules, contains('function isInventoryIdentityPreserved(inventoryId)'));
      expect(
          rules,
          contains(
              "request.resource.data.get('quantity', -1) <= resource.data.get('quantity', -1)"));
      expect(
          rules,
          contains(
              "request.resource.data.get('quantity', -1) >= resource.data.get('quantity', -1)"));
      expect(
          rules,
          contains(
              "request.resource.data.get('itemId', '') == resource.data.get('itemId', '')"));
      expect(
          rules,
          contains(
              "request.resource.data.get('itemType', '') == resource.data.get('itemType', '')"));
      expect(
          rules,
          contains(
              'allow delete: if resource == null || isOwner(merchantId);'));
    });

    test('unknown merchant subcollection writes are owner only', () {
      expect(rules, contains('match /{subcollection=**}'));
      expect(rules, contains('allow read: if isOwner(merchantId);'));
      expect(rules, contains('allow write: if isOwner(merchantId);'));
    });
  });
}

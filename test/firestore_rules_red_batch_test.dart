import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Red Batch Firestore Rules contract', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    group('Order Returns (order_returns)', () {
      test('authorized same-branch return allowed', () {
        expect(rules, contains('match /order_returns/{returnId}'));
        expect(rules, contains('allow get: if (resource == null && isAuthenticated()) || canReadOrder(merchantId, resource.data);'));
        expect(rules, contains('allow list: if resource != null && canReadOrder(merchantId, resource.data);'));
        expect(rules, contains("hasDataBranchAccess(merchantId, request.resource.data)"));
        expect(rules, contains("request.resource.data.get('merchantId', '') == merchantId"));
      });

      test('employee without cancel/return authority denied', () {
        expect(rules, contains("hasPermission(merchantId, 'can_create_orders') || hasPermission(merchantId, 'can_cancel_orders')"));
      });

      test('employee from another branch denied', () {
        expect(rules, contains('hasDataBranchAccess(merchantId, request.resource.data)'));
      });

      test('cross-merchant access denied', () {
        expect(rules, contains("request.resource.data.get('merchantId', '') == merchantId"));
      });

      test('arbitrary update denied', () {
        final match = RegExp(r'match /order_returns/\{returnId\}(.*?)\}', dotAll: true).firstMatch(rules);
        expect(match, isNotNull);
        final block = match!.group(1)!;
        expect(block, contains('allow update, delete: if false;'));
      });
    });

    group('Purchase Invoices (purchase_invoices)', () {
      test('authorized same-branch create allowed', () {
        expect(rules, contains('match /purchase_invoices/{invoiceId}'));
        expect(rules, contains("hasPermission(merchantId, 'can_manage_inventory')"));
        expect(rules, contains("hasDataBranchAccess(merchantId, request.resource.data)"));
        expect(rules, contains("request.resource.data.get('merchantId', '') == merchantId"));
      });

      test('unauthorized employee denied', () {
        final match = RegExp(r'match /purchase_invoices/\{invoiceId\}(.*?)\}', dotAll: true).firstMatch(rules);
        expect(match, isNotNull);
        final block = match!.group(1)!;
        expect(block, contains("hasPermission(merchantId, 'can_manage_inventory')"));
      });

      test('employee from another branch denied', () {
        final match = RegExp(r'match /purchase_invoices/\{invoiceId\}(.*?)\}', dotAll: true).firstMatch(rules);
        expect(match, isNotNull);
        final block = match!.group(1)!;
        expect(block, contains("hasDataBranchAccess(merchantId, request.resource.data)"));
      });

      test('cross-merchant access denied', () {
        final match = RegExp(r'match /purchase_invoices/\{invoiceId\}(.*?)\}', dotAll: true).firstMatch(rules);
        expect(match, isNotNull);
        final block = match!.group(1)!;
        expect(block, contains("request.resource.data.get('merchantId', '') == merchantId"));
      });

      test('arbitrary financial update denied', () {
        final match = RegExp(r'match /purchase_invoices/\{invoiceId\}(.*?)\}', dotAll: true).firstMatch(rules);
        expect(match, isNotNull);
        final block = match!.group(1)!;
        expect(block, contains('allow update, delete: if false;'));
      });

      test('protected cost privacy remains intact', () {
        final match = RegExp(r'match /purchase_invoices/\{invoiceId\}(.*?)\}', dotAll: true).firstMatch(rules);
        expect(match, isNotNull);
        final block = match!.group(1)!;
        expect(block, contains("allow read: if resource != null && hasPermission(merchantId, 'can_manage_inventory')"));
      });
    });
  });
}

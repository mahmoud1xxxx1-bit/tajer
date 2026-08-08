import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/branches/domain/branch.dart';
import 'package:tajer/features/expenses/domain/expense.dart';
import 'package:tajer/features/inventory_log/domain/inventory_log.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/shifts/domain/shift.dart';

void main() {
  group('Multi-branch backward compatibility', () {
    test('missing branchId resolves to main branch', () {
      expect(resolveBranchId(null), BranchIds.main);
      expect(resolveBranchId(''), BranchIds.main);
      expect(resolveBranchId('  '), BranchIds.main);
      expect(resolveBranchId('branch-2'), 'branch-2');
    });

    test('legacy order without branchId belongs to main branch', () {
      final order = AppOrder.fromJson({
        'id': 'legacy-order',
        'merchantId': 'merchant-1',
        'customerId': 'walk_in',
        'customerName': 'Walk in',
        'items': const [],
        'total': 0,
        'createdAt': DateTime(2026, 8, 8).toIso8601String(),
      });

      expect(order.branchId, BranchIds.main);
      expect(order.toJson()['branchId'], BranchIds.main);
    });

    test('new order preserves explicit branchId snapshot', () {
      final order = AppOrder(
        id: 'order-2',
        merchantId: 'merchant-1',
        branchId: 'branch-2',
        customerId: 'walk_in',
        customerName: 'Walk in',
        total: 50,
        createdAt: DateTime(2026, 8, 8),
      );

      final json = order.toJson();
      expect(json['branchId'], 'branch-2');
      expect(AppOrder.fromJson(json).branchId, 'branch-2');
    });

    test('legacy shift without branchId belongs to main branch', () {
      final shift = Shift.fromJson({
        'id': 'shift-107',
        'merchantId': 'merchant-1',
        'employeeId': 'owner',
        'employeeName': 'Owner',
        'startTime': DateTime(2026, 8, 8).toIso8601String(),
        'startCash': 100,
        'status': 'closed',
      });
      expect(shift.branchId, BranchIds.main);
      expect(shift.toJson()['branchId'], BranchIds.main);
    });

    test('new shift preserves explicit branchId snapshot', () {
      final shift = Shift(
        id: 'shift-2',
        merchantId: 'merchant-1',
        branchId: 'branch-2',
        employeeId: 'owner',
        employeeName: 'Owner',
        startTime: DateTime(2026, 8, 8, 9),
        startCash: 200,
        status: 'open',
      );
      final json = shift.toJson();
      expect(json['branchId'], 'branch-2');
      expect(Shift.fromJson(json).branchId, 'branch-2');
    });

    test('legacy expense without branchId and shiftId remains readable', () {
      final now = DateTime(2026, 8, 8);
      final expense = Expense.fromJson({
        'id': 'expense-107',
        'merchantId': 'merchant-1',
        'title': 'Rent',
        'amount': 250,
        'date': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });
      expect(expense.branchId, BranchIds.main);
      expect(expense.shiftId, isNull);
      expect(expense.toJson()['branchId'], BranchIds.main);
    });

    test('new expense preserves exact branch and shift snapshots', () {
      final now = DateTime(2026, 8, 8, 11);
      final expense = Expense(
        id: 'expense-2',
        merchantId: 'merchant-1',
        branchId: 'branch-2',
        shiftId: 'shift-2',
        title: 'Branch supplies',
        amount: 75,
        date: now,
        createdAt: now,
      );
      final json = expense.toJson();
      expect(json['branchId'], 'branch-2');
      expect(json['shiftId'], 'shift-2');
      final decoded = Expense.fromJson(json);
      expect(decoded.branchId, 'branch-2');
      expect(decoded.shiftId, 'shift-2');
    });

    test('legacy inventory log without branchId belongs to main branch', () {
      final log = InventoryLog.fromJson({
        'id': 'log-107',
        'merchantId': 'merchant-1',
        'productId': 'p1',
        'productName': 'Coffee',
        'changeQuantity': -1,
        'previousQuantity': 10,
        'newQuantity': 9,
        'reason': 'sale',
        'date': DateTime(2026, 8, 8).toIso8601String(),
      });
      expect(log.branchId, BranchIds.main);
      expect(log.toJson()['branchId'], BranchIds.main);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/branches/domain/branch.dart';
import 'package:tajer/features/customers/domain/customer_debt_payment.dart';
import 'package:tajer/features/expenses/domain/expense.dart';
import 'package:tajer/features/inventory_log/domain/inventory_log.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/shifts/domain/shift.dart';
import 'package:tajer/features/suppliers/domain/supplier_transaction.dart';

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

    test('legacy supplier transaction defaults to main and no linked expense', () {
      final now = DateTime(2026, 8, 8, 12);
      final tx = SupplierTransaction.fromJson({
        'id': 'supplier-tx-107',
        'supplierId': 'supplier-1',
        'merchantId': 'merchant-1',
        'amount': 100,
        'type': 'payment',
        'description': 'legacy payment',
        'date': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });
      expect(tx.branchId, BranchIds.main);
      expect(tx.expenseId, isNull);
    });

    test('new supplier payment preserves branch and exact linked expense', () {
      final now = DateTime(2026, 8, 8, 13);
      final tx = SupplierTransaction(
        id: 'supplier-tx-2',
        supplierId: 'supplier-1',
        merchantId: 'merchant-1',
        branchId: 'branch-2',
        expenseId: 'expense-supplier-2',
        amount: 100,
        type: 'payment',
        description: 'payment',
        date: now,
        createdAt: now,
      );
      final json = tx.toJson();
      expect(json['branchId'], 'branch-2');
      expect(json['expenseId'], 'expense-supplier-2');
      final decoded = SupplierTransaction.fromJson(json);
      expect(decoded.branchId, 'branch-2');
      expect(decoded.expenseId, 'expense-supplier-2');
    });

    test('customer debt payment preserves branch, shift and allocations', () {
      final payment = CustomerDebtPayment(
        id: 'customer-payment-1',
        merchantId: 'merchant-1',
        customerId: 'customer-1',
        branchId: 'branch-2',
        shiftId: 'shift-2',
        amount: 75,
        paymentMethod: 'cash',
        allocations: const [
          CustomerDebtAllocation(orderId: 'order-a', amount: 50),
          CustomerDebtAllocation(orderId: 'order-b', amount: 25),
        ],
        createdAt: DateTime(2026, 8, 8, 14),
      );
      final decoded = CustomerDebtPayment.fromJson(payment.toJson());
      expect(decoded.branchId, 'branch-2');
      expect(decoded.shiftId, 'shift-2');
      expect(decoded.amount, 75);
      expect(decoded.allocations.length, 2);
      expect(decoded.allocations[0].orderId, 'order-a');
      expect(decoded.allocations[1].amount, 25);
    });

    test('customer debt payment missing branchId safely resolves to main', () {
      final decoded = CustomerDebtPayment.fromJson({
        'id': 'customer-payment-legacy-shape',
        'merchantId': 'merchant-1',
        'customerId': 'customer-1',
        'amount': 20,
        'paymentMethod': 'cash',
        'allocations': const [],
        'createdAt': DateTime(2026, 8, 8, 15).toIso8601String(),
      });
      expect(decoded.branchId, BranchIds.main);
      expect(decoded.shiftId, isNull);
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

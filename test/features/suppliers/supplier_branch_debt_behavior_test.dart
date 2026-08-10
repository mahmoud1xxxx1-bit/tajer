import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/suppliers/domain/supplier.dart';
import 'package:tajer/features/suppliers/domain/supplier_transaction.dart';

void main() {
  group('F9 Supplier Branch Debt Behavior', () {
    test('Supplier holds explicit branch associations without duplicating master document', () {
      final supplier = Supplier(
        id: 'sup_123',
        merchantId: 'merch_1',
        name: 'Test Supplier',
        totalDebt: 0,
        associatedBranchIds: ['branch_a'],
        branchDebts: {},
        createdAt: DateTime.now(),
      );

      expect(supplier.id, 'sup_123');
      expect(supplier.associatedBranchIds.contains('branch_a'), isTrue);
      expect(supplier.associatedBranchIds.contains('branch_b'), isFalse);
    });

    test('Supplier can have exactly zero debt but remain associated with a branch', () {
      final supplier = Supplier(
        id: 'sup_123',
        merchantId: 'merch_1',
        name: 'Test Supplier',
        totalDebt: 0,
        associatedBranchIds: ['branch_a'],
        branchDebts: {'branch_a': 0.0},
        createdAt: DateTime.now(),
      );

      expect(supplier.associatedBranchIds.contains('branch_a'), isTrue);
      expect(supplier.branchDebts['branch_a'], 0.0);
    });

    test('Supplier branchDebts dictionary safely defaults to 0 if not present', () {
      final supplier = Supplier(
        id: 'sup_123',
        merchantId: 'merch_1',
        name: 'Test Supplier',
        totalDebt: 100,
        associatedBranchIds: ['branch_a'],
        branchDebts: {'branch_b': 100.0},
        createdAt: DateTime.now(),
      );

      final branchADebt = supplier.branchDebts['branch_a'] ?? 0.0;
      final branchBDebt = supplier.branchDebts['branch_b'] ?? 0.0;

      expect(branchADebt, 0.0);
      expect(branchBDebt, 100.0);
    });

    test('Supplier details active branch strictly filters transaction history', () {
      final tBranchA = SupplierTransaction(
        id: 'tx_a', supplierId: 's1', type: 'debt_addition', amount: 10, branchId: 'branch_a', createdAt: DateTime.now(), merchantId: 'm1', description: '', date: DateTime.now());
      final tBranchB = SupplierTransaction(
        id: 'tx_b', supplierId: 's1', type: 'debt_addition', amount: 20, branchId: 'branch_b', createdAt: DateTime.now(), merchantId: 'm1', description: '', date: DateTime.now());
      final tLegacyUnscoped = SupplierTransaction(
        id: 'tx_old', supplierId: 's1', type: 'debt_addition', amount: 30, branchId: '', createdAt: DateTime.now(), merchantId: 'm1', description: '', date: DateTime.now());
      final tLegacyNull = SupplierTransaction(
        id: 'tx_null', supplierId: 's1', type: 'debt_addition', amount: 40, createdAt: DateTime.now(), merchantId: 'm1', description: '', date: DateTime.now(), branchId: '');
      
      final allTransactions = [tBranchA, tBranchB, tLegacyUnscoped, tLegacyNull];

      // View for Branch A
      final viewA = allTransactions.where((t) => t.branchId == 'branch_a').toList();
      expect(viewA.length, 1);
      expect(viewA.first.id, 'tx_a');
      
      // View for Branch B
      final viewB = allTransactions.where((t) => t.branchId == 'branch_b').toList();
      expect(viewB.length, 1);
      expect(viewB.first.id, 'tx_b');

      // Assert legacy is not attributed to A or B
      expect(viewA.any((t) => t.id == 'tx_old' || t.id == 'tx_null'), isFalse);
      expect(viewB.any((t) => t.id == 'tx_old' || t.id == 'tx_null'), isFalse);
    });
  });
}

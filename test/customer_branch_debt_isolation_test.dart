import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/customers/domain/customer.dart';
import 'package:tajer/features/customers/domain/customer_debt_payment.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

void main() {
  group('Branch-scoped customer and debt isolation', () {
    AppOrder order({
      required String id,
      required String branchId,
      required double total,
      required double paidAmount,
      required bool isCredit,
    }) {
      return AppOrder(
        id: id,
        merchantId: 'merchant-1',
        branchId: branchId,
        customerId: 'customer-1',
        customerName: 'Customer',
        items: [
          CartItem(
            productId: 'product-1',
            productName: 'Product',
            quantity: 1,
            price: total,
            total: total,
          ),
        ],
        total: total,
        paidAmount: paidAmount,
        isCredit: isCredit,
        paymentMethod: 'cash',
        createdAt: DateTime(2026, 8, 9),
      );
    }

    CustomerDebtPayment debtPayment({
      required String id,
      required String branchId,
      required double amount,
    }) {
      return CustomerDebtPayment(
        id: id,
        merchantId: 'merchant-1',
        customerId: 'customer-1',
        branchId: branchId,
        amount: amount,
        paymentMethod: 'cash',
        allocations: const [],
        createdAt: DateTime(2026, 8, 9),
      );
    }

    test('legacy customers without branchId are treated as main branch', () {
      final customer = Customer.fromJson({
        'id': 'legacy-customer',
        'merchantId': 'merchant-1',
        'name': 'Legacy',
        'phone': '0500000000',
      });

      expect(customer.branchId, 'main');
      expect(customer.toJson()['branchId'], 'main');
    });

    test('new customer serialization preserves branchId', () {
      final customer = Customer(
        id: 'customer-branch-2',
        merchantId: 'merchant-1',
        branchId: 'branch-2',
        name: 'Ahmed',
        phone: '0500000000',
        createdAt: DateTime(2026, 8, 9),
      );

      expect(customer.toJson()['branchId'], 'branch-2');
      expect(Customer.fromJson(customer.toJson()).branchId, 'branch-2');
    });

    test('debt collection is not counted as duplicate sales revenue', () {
      final service = ReportsService(
        [
          order(
            id: 'credit-sale',
            branchId: 'main',
            total: 40,
            paidAmount: 40,
            isCredit: true,
          ),
        ],
        const [],
        const [],
        const [],
        const [],
        debtPayments: [
          debtPayment(
            id: 'collection',
            branchId: 'main',
            amount: 30,
          ),
        ],
      );

      expect(service.totalRevenue, 40);
      expect(service.paymentMethodsBreakdown['cash'], 70);
    });

    test('repository enforces customer, order, and shift branch matching', () {
      final source =
          File('lib/features/orders/data/branch_aware_order_repository.dart')
              .readAsStringSync();

      expect(
          source, contains('Customer account belongs to a different branch'));
      expect(source, contains('customerBranchId != branchId'));
      expect(source, contains('orderBranchId != branchId'));
      expect(source, contains('shiftBranchId != branchId'));
    });

    test('Firestore payment rule checks customer branch', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('function isCustomerDebtPaymentCreate'));
      expect(
        rules,
        contains(
          "customerDoc.data.get('branchId', 'main') == request.resource.data.get('branchId', 'main')",
        ),
      );
      expect(rules, contains('allow create: if isCustomerDebtPaymentCreate'));
    });
  });
}

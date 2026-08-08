import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/customers/domain/customer_debt_payment.dart';

void main() {
  group('CustomerDebtPayment', () {
    test('preserves branch, shift, method and invoice allocations', () {
      final createdAt = DateTime.utc(2026, 8, 8, 12, 30);
      final payment = CustomerDebtPayment(
        id: 'pay-1',
        merchantId: 'merchant-1',
        customerId: 'customer-1',
        branchId: 'branch-jeddah',
        shiftId: 'shift-77',
        amount: 150.0,
        paymentMethod: 'card',
        allocations: const [
          CustomerDebtAllocation(orderId: 'order-1', amount: 100.0),
          CustomerDebtAllocation(orderId: 'order-2', amount: 50.0),
        ],
        createdAt: createdAt,
      );

      final restored = CustomerDebtPayment.fromJson(payment.toJson());

      expect(restored.id, 'pay-1');
      expect(restored.merchantId, 'merchant-1');
      expect(restored.customerId, 'customer-1');
      expect(restored.branchId, 'branch-jeddah');
      expect(restored.shiftId, 'shift-77');
      expect(restored.amount, 150.0);
      expect(restored.paymentMethod, 'card');
      expect(restored.allocations, hasLength(2));
      expect(restored.allocations[0].orderId, 'order-1');
      expect(restored.allocations[0].amount, 100.0);
      expect(restored.allocations[1].orderId, 'order-2');
      expect(restored.allocations[1].amount, 50.0);
      expect(restored.createdAt.toUtc(), createdAt);
    });

    test('legacy payment without branchId safely belongs to main branch', () {
      final payment = CustomerDebtPayment.fromJson({
        'id': 'legacy-pay',
        'merchantId': 'merchant-1',
        'customerId': 'customer-1',
        'amount': 75,
        'paymentMethod': 'cash',
        'allocations': [
          {'orderId': 'legacy-order', 'amount': 75},
        ],
        'createdAt': '2026-08-08T10:00:00.000Z',
      });

      expect(payment.branchId, 'main');
      expect(payment.shiftId, isNull);
      expect(payment.amount, 75.0);
      expect(payment.allocations.single.orderId, 'legacy-order');
      expect(payment.allocations.single.amount, 75.0);
    });

    test('allocation amounts round-trip as doubles', () {
      const allocation = CustomerDebtAllocation(
        orderId: 'order-decimal',
        amount: 12.75,
      );

      final restored = CustomerDebtAllocation.fromJson(allocation.toJson());
      expect(restored.orderId, 'order-decimal');
      expect(restored.amount, 12.75);
    });
  });
}

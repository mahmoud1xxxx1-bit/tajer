import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/branches/domain/branch.dart';
import 'package:tajer/features/orders/domain/order.dart';

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
  });
}

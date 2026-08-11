from pathlib import Path

# Triggered one-shot patch for the accounting audit branch.
p = Path('lib/features/orders/data/branch_aware_order_repository.dart')
s = p.read_text()

old = """      if (currentStatus == newStatus) return;
      if (currentStatus != order.status || data['statusTransition'] != null) {
        throw Exception(
          'Order status changed on another device. Please refresh.',
        );
      }
"""
new = """      if (currentStatus == newStatus) return;
      if (currentStatus != order.status || data['statusTransition'] != null) {
        throw Exception(
          'Order status changed on another device. Please refresh.',
        );
      }
      if (currentStatus == 'cancelled' && newStatus != 'cancelled') {
        throw Exception(
          'A cancelled invoice is final and cannot be reopened. Create a new sale instead.',
        );
      }
"""
if s.count(old) != 1:
    raise SystemExit(f'status guard anchor mismatch: {s.count(old)}')
s = s.replace(old, new, 1)

old = """        if (!shiftSnap.exists ||
            shiftData == null ||
            shiftData['merchantId'] != canonicalOrder.merchantId ||
            (shiftData['branchId']?.toString() ?? 'main') !=
                canonicalOrder.branchId) {
          throw Exception(
            'Order refund shift does not match the order merchant and branch.',
          );
        }
"""
new = """        if (!shiftSnap.exists ||
            shiftData == null ||
            shiftData['merchantId'] != canonicalOrder.merchantId ||
            (shiftData['branchId']?.toString() ?? 'main') !=
                canonicalOrder.branchId) {
          throw Exception(
            'Order refund shift does not match the order merchant and branch.',
          );
        }
        if (shiftData['status']?.toString() != 'open' ||
            shiftData['endTime'] != null) {
          throw Exception(
            'A sale cannot be voided after its shift is closed. Use the return workflow so the reversal is recorded in the current shift.',
          );
        }
"""
if s.count(old) != 1:
    raise SystemExit(f'closed shift anchor mismatch: {s.count(old)}')
s = s.replace(old, new, 1)

p.write_text(s)
print('Void/closed-shift accounting guards applied.')

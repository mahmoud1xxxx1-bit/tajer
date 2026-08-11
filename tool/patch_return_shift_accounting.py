from pathlib import Path

# One-shot deterministic patch for the accounting audit branch.
p = Path('lib/features/orders/data/branch_aware_order_repository.dart')
s = p.read_text()

old = """    final returnRef = firestore
        .collection('merchants')
        .doc(originalOrder.merchantId)
        .collection('returns')
        .doc(orderReturn.id);
"""
new = """    final returnRef = firestore
        .collection('merchants')
        .doc(originalOrder.merchantId)
        .collection('order_returns')
        .doc(orderReturn.id);
"""
if s.count(old) != 1:
    raise SystemExit(f'returnRef anchor mismatch: {s.count(old)}')
s = s.replace(old, new, 1)

old = """      // DO ALL READS FIRST
      DocumentReference<Map<String, dynamic>>? shiftRef;
      DocumentSnapshot<Map<String, dynamic>>? shiftSnap;
      if (orderReturn.returnedTotal > 0) {
        final shiftId = canonicalOrder.shiftId;
        if (shiftId != null && shiftId.isNotEmpty) {
          shiftRef = firestore.collection('shifts').doc(shiftId);
          shiftSnap = await tx.get(shiftRef);
          if (shiftSnap.exists) {
            final shiftBranchId =
                shiftSnap.data()?['branchId']?.toString() ?? 'main';
            if (shiftBranchId != canonicalOrder.branchId) {
              throw Exception('Order branch does not match the active shift');
            }
          }
        }
      }
"""
new = """      // Returns are new accounting events and must be posted to the
      // CURRENT open shift, never back into the original sale's closed shift.
      DocumentReference<Map<String, dynamic>>? shiftRef;
      if (orderReturn.returnedTotal > 0) {
        final shiftId = orderReturn.shiftId;
        if (shiftId == null || shiftId.isEmpty) {
          throw Exception('An open shift is required to record a return.');
        }
        shiftRef = firestore.collection('shifts').doc(shiftId);
        final shiftSnap = await tx.get(shiftRef);
        if (!shiftSnap.exists || shiftSnap.data() == null) {
          throw Exception('Return shift not found.');
        }
        final shiftData = shiftSnap.data()!;
        final shiftBranchId = shiftData['branchId']?.toString() ?? 'main';
        final shiftStatus = shiftData['status']?.toString();
        if (shiftBranchId != canonicalOrder.branchId ||
            shiftStatus != 'open' ||
            shiftData['endTime'] != null) {
          throw Exception(
            'Return must be recorded in the current open shift of the sale branch.',
          );
        }
      }
"""
if s.count(old) != 1:
    raise SystemExit(f'shift read anchor mismatch: {s.count(old)}')
s = s.replace(old, new, 1)

old = """      // NOW DO ALL WRITES
      if (orderReturn.returnedTotal > 0) {
        if (shiftRef != null && shiftSnap != null && shiftSnap.exists) {
          final updates = <String, dynamic>{};
          if (canonicalOrder.paymentMethod == 'cash') {
            updates['cashSales'] = FieldValue.increment(
              -orderReturn.returnedTotal,
            );
          }
          if ([
            'card',
            'mada',
            'apple_pay',
          ].contains(canonicalOrder.paymentMethod)) {
            updates['cardTotal'] = FieldValue.increment(
              -orderReturn.returnedTotal,
            );
          }
          if (canonicalOrder.paymentMethod == 'transfer') {
            updates['transferTotal'] = FieldValue.increment(
              -orderReturn.returnedTotal,
            );
          }
          if (canonicalOrder.paymentMethod == 'split') {
            final originalCash = canonicalOrder.splitCashAmount ?? 0.0;
            final originalCard = canonicalOrder.splitNetworkAmount ?? 0.0;
            final originalSplitPaid = originalCash + originalCard;
            if (originalSplitPaid <= 0.000001) {
              throw Exception('بيانات الدفع المقسم الأصلية غير صالحة للمرتجع.');
            }
            final cashRefund =
                orderReturn.returnedTotal * (originalCash / originalSplitPaid);
            final cardRefund = orderReturn.returnedTotal - cashRefund;
            if (cashRefund > 0.000001) {
              updates['cashSales'] = FieldValue.increment(-cashRefund);
            }
            if (cardRefund > 0.000001) {
              updates['cardTotal'] = FieldValue.increment(-cardRefund);
            }
          }
          if (updates.isNotEmpty) {
            tx.update(shiftRef, updates);
          }
        }
"""
new = """      // NOW DO ALL WRITES
      if (orderReturn.returnedTotal > 0) {
        if (shiftRef != null) {
          final updates = <String, dynamic>{
            'totalTax': FieldValue.increment(-orderReturn.returnedTax),
          };
          if (canonicalOrder.paymentMethod == 'cash') {
            updates['refundsCash'] =
                FieldValue.increment(orderReturn.returnedTotal);
          }
          if ([
            'card',
            'mada',
            'apple_pay',
          ].contains(canonicalOrder.paymentMethod)) {
            updates['refundsCard'] =
                FieldValue.increment(orderReturn.returnedTotal);
          }
          if (canonicalOrder.paymentMethod == 'transfer') {
            updates['refundsTransfer'] =
                FieldValue.increment(orderReturn.returnedTotal);
          }
          if (canonicalOrder.paymentMethod == 'split') {
            final originalCash = canonicalOrder.splitCashAmount ?? 0.0;
            final originalCard = canonicalOrder.splitNetworkAmount ?? 0.0;
            final originalSplitPaid = originalCash + originalCard;
            if (originalSplitPaid <= 0.000001) {
              throw Exception('بيانات الدفع المقسم الأصلية غير صالحة للمرتجع.');
            }
            final cashRefund =
                orderReturn.returnedTotal * (originalCash / originalSplitPaid);
            final cardRefund = orderReturn.returnedTotal - cashRefund;
            if (cashRefund > 0.000001) {
              updates['refundsCash'] = FieldValue.increment(cashRefund);
            }
            if (cardRefund > 0.000001) {
              updates['refundsCard'] = FieldValue.increment(cardRefund);
            }
          }
          tx.update(shiftRef, updates);
        }
"""
if s.count(old) != 1:
    raise SystemExit(f'shift write anchor mismatch: {s.count(old)}')
s = s.replace(old, new, 1)

p.write_text(s)
print('Return shift accounting patch applied.')

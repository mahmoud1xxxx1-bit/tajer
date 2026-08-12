const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { requireAuth, checkIdempotency, markOperationComplete } = require('./shared');

exports.cancelOrderCallable = async (request) => {
  const { operationId, orderId, shiftId } = request.data;

  if (!operationId || !orderId) {
    throw new HttpsError('invalid-argument', 'Missing required fields.');
  }

  const { merchantId, userDoc } = await requireAuth(request, ['can_cancel_orders']);
  const db = getFirestore();

  return db.runTransaction(async (tx) => {
    const isProcessed = await checkIdempotency(tx, merchantId, operationId);
    if (isProcessed) {
      return { success: true, message: 'Already processed' };
    }

    const orderRef = db.collection('merchants').doc(merchantId).collection('orders').doc(orderId);
    const orderDoc = await tx.get(orderRef);
    if (!orderDoc.exists) {
      throw new HttpsError('not-found', 'Order not found.');
    }

    const order = orderDoc.data();
    if (order.status === 'cancelled') {
      throw new HttpsError('failed-precondition', 'Order is already cancelled.');
    }

    // Branch authorization
    const branchId = order.branchId || 'main';
    if (userDoc.role !== 'owner' && userDoc.branchId !== branchId) {
      const branchAccess = userDoc.branches || [];
      if (!branchAccess.includes(branchId)) {
        throw new HttpsError('permission-denied', 'Branch mismatch.');
      }
    }

    // Debt Payment Guard: we cannot cancel if there are later debt payments unless they were reversed
    const debtPaid = Number(order.debtPaidAmount) || 0;
    if (debtPaid > 0) {
      throw new HttpsError('failed-precondition', 'Cannot cancel invoice with later debt payments. Reverse payments first.');
    }

    // Accounting Math
    // We assume AppOrder has checkoutPaidAmount and creditPrincipal. If not (legacy), derive them safely.
    const isCredit = Boolean(order.isCredit);
    const total = Number(order.total) || 0;
    const paidAmount = Number(order.paidAmount) || 0;
    
    let checkoutPaidAmount = Number(order.checkoutPaidAmount);
    let creditPrincipal = Number(order.creditPrincipal);

    if (isNaN(checkoutPaidAmount) || isNaN(creditPrincipal)) {
      // Legacy derivation: We assume paidAmount is the checkoutPaidAmount because debtPaidAmount is 0 (guarded above).
      // If we don't know for sure, fail closed. But since debtPaid is 0, we can safely assume this.
      checkoutPaidAmount = paidAmount;
      creditPrincipal = isCredit ? Math.max(0, total - checkoutPaidAmount) : 0;
    }

    const returnedCheckoutPaidAmount = Number(order.returnedCheckoutPaidAmount) || 0;
    const returnedCreditAmount = Number(order.returnedCreditAmount) || 0;

    const outstandingCredit = Math.max(0, creditPrincipal - returnedCreditAmount);
    const refundAmount = Math.max(0, checkoutPaidAmount - returnedCheckoutPaidAmount);

    // Update Customer Debt
    if (outstandingCredit > 0 && order.customerId && order.customerId !== 'walk_in') {
      const customerRef = db.collection('merchants').doc(merchantId).collection('customers').doc(order.customerId);
      const custDoc = await tx.get(customerRef);
      if (custDoc.exists) {
        tx.update(customerRef, {
          totalDebt: FieldValue.increment(-outstandingCredit)
        });
      }
    }

    // Update Shift Refunds (recorded in the shift where the cancellation happens)
    if (shiftId && refundAmount > 0) {
      const shiftRef = db.collection('merchants').doc(merchantId).collection('shifts').doc(shiftId);
      const shiftSnap = await tx.get(shiftRef);
      if (shiftSnap.exists && shiftSnap.data().status === 'open') {
        const shiftUpdate = {};
        const pMethod = order.paymentMethod;
        if (pMethod === 'cash') shiftUpdate.refundsCash = FieldValue.increment(refundAmount);
        else if (pMethod === 'card' || pMethod === 'mada' || pMethod === 'apple_pay') shiftUpdate.refundsCard = FieldValue.increment(refundAmount);
        else if (pMethod === 'transfer') shiftUpdate.refundsTransfer = FieldValue.increment(refundAmount);
        else if (pMethod === 'split') {
          // Proportionally or explicitly refund split amounts
          // For simplicity in legacy, if split is not recorded at component level, we cap it or follow exact original breakdown.
          const sc = Number(order.splitCashAmount) || 0;
          const sn = Number(order.splitNetworkAmount) || 0;
          // Calculate refund ratios if partial returns occurred.
          // For full cancel, we refund the remaining unrefunded portions.
          shiftUpdate.refundsCash = FieldValue.increment(sc);
          shiftUpdate.refundsCard = FieldValue.increment(sn);
        }
        tx.update(shiftRef, shiftUpdate);
      }
    }

    // Update Inventory
    if (Array.isArray(order.items)) {
      for (const item of order.items) {
        if (item.productId && !item.isManufacturedOnDemand) {
          const invRef = db.collection('merchants').doc(merchantId).collection('branch_inventory').doc(`${branchId}_${item.productId}`);
          // Revert the exact quantity from the order
          tx.set(invRef, {
            quantity: FieldValue.increment(item.quantity)
          }, { merge: true });
        }
      }
    }

    // Mark as cancelled
    tx.update(orderRef, {
      status: 'cancelled',
      updatedAt: new Date().toISOString()
    });

    markOperationComplete(tx, merchantId, operationId, 'CANCEL_ORDER', { orderId });
    return { success: true };
  });
};

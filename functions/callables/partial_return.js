const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { requireAuth, checkIdempotency, markOperationComplete } = require('./shared');

exports.partialReturnCallable = async (request) => {
  const { operationId, orderId, returnId, returnedItems, shiftId } = request.data;

  if (!operationId || !orderId || !returnId || !returnedItems || !Array.isArray(returnedItems)) {
    throw new HttpsError('invalid-argument', 'Missing required fields.');
  }

  const { merchantId, userDoc } = await requireAuth(request, ['can_cancel_orders']);
  const db = getFirestore();

  return db.runTransaction(async (tx) => {
    const isProcessed = await checkIdempotency(tx, merchantId, operationId);
    if (isProcessed) {
      return { success: true, message: 'Already processed' };
    }

    // 1. Verify returnId hasn't been used (second idempotency check)
    const returnRef = db.collection('merchants').doc(merchantId).collection('returns').doc(returnId);
    const existingReturn = await tx.get(returnRef);
    if (existingReturn.exists) {
      throw new HttpsError('already-exists', 'Return ID already processed.');
    }

    // 2. Read Order
    const orderRef = db.collection('merchants').doc(merchantId).collection('orders').doc(orderId);
    const orderDoc = await tx.get(orderRef);
    if (!orderDoc.exists) {
      throw new HttpsError('not-found', 'Order not found.');
    }
    const order = orderDoc.data();
    if (order.status === 'cancelled') {
      throw new HttpsError('failed-precondition', 'Cannot partially return a cancelled order.');
    }

    const branchId = order.branchId || 'main';
    if (userDoc.role !== 'owner' && userDoc.branchId !== branchId) {
      const branchAccess = userDoc.branches || [];
      if (!branchAccess.includes(branchId)) {
        throw new HttpsError('permission-denied', 'Branch mismatch.');
      }
    }

    // 3. Process returned items and compute exact financial return amount
    const previouslyReturned = order.returnedQuantities || {};
    let computedReturnAmount = 0;
    const inventoryUpdates = [];
    const newReturnedQuantities = { ...previouslyReturned };

    for (const retItem of returnedItems) {
      const lineId = retItem.lineId;
      const originalLine = order.items.find(i => i.lineId === lineId);
      if (!originalLine) {
        throw new HttpsError('invalid-argument', `Line item not found: ${lineId}`);
      }

      const currentRetQty = previouslyReturned[lineId] || 0;
      const newRetQty = currentRetQty + retItem.quantity;
      if (newRetQty > originalLine.quantity) {
        throw new HttpsError('failed-precondition', 'Return quantity exceeds sold quantity.');
      }

      newReturnedQuantities[lineId] = newRetQty;

      // Price calculation: if discount was applied, return amount should reflect exact paid per unit
      // This is complex, but assuming total line total / quantity = unit paid price
      const unitPrice = originalLine.total / originalLine.quantity;
      computedReturnAmount += (unitPrice * retItem.quantity);

      if (originalLine.productId && !originalLine.isManufacturedOnDemand) {
        inventoryUpdates.push({
          docId: `${branchId}_${originalLine.productId}`,
          qty: retItem.quantity
        });
      }
    }

    // 4. Financial Distribution (Credit vs Checkout Cash)
    let checkoutPaidAmount = Number(order.checkoutPaidAmount);
    let creditPrincipal = Number(order.creditPrincipal);
    if (isNaN(checkoutPaidAmount) || isNaN(creditPrincipal)) {
      checkoutPaidAmount = Number(order.paidAmount) || 0;
      creditPrincipal = order.isCredit ? Math.max(0, Number(order.total) - checkoutPaidAmount) : 0;
    }

    let returnedCheckoutPaidAmount = Number(order.returnedCheckoutPaidAmount) || 0;
    let returnedCreditAmount = Number(order.returnedCreditAmount) || 0;

    let remainingCreditToReturn = Math.max(0, creditPrincipal - returnedCreditAmount);
    
    let amountToRefundCash = 0;
    let amountToDeductCredit = 0;
    let returnBalance = computedReturnAmount;

    // First deduct from outstanding credit principal
    if (returnBalance > 0 && remainingCreditToReturn > 0) {
      const deduct = Math.min(returnBalance, remainingCreditToReturn);
      amountToDeductCredit = deduct;
      returnBalance -= deduct;
      returnedCreditAmount += deduct;
    }

    // The rest is a cash/card refund
    if (returnBalance > 0) {
      // Ensure we don't refund more than what was paid at checkout!
      const availableToRefund = Math.max(0, checkoutPaidAmount - returnedCheckoutPaidAmount);
      const refund = Math.min(returnBalance, availableToRefund);
      amountToRefundCash = refund;
      returnedCheckoutPaidAmount += refund;
    }

    // 5. Customer Debt Update
    if (amountToDeductCredit > 0 && order.customerId && order.customerId !== 'walk_in') {
      const customerRef = db.collection('merchants').doc(merchantId).collection('customers').doc(order.customerId);
      const custDoc = await tx.get(customerRef);
      if (custDoc.exists) {
        tx.update(customerRef, {
          totalDebt: FieldValue.increment(-amountToDeductCredit)
        });
      }
    }

    // 6. Shift Refund Update
    if (shiftId && amountToRefundCash > 0) {
      const shiftRef = db.collection('merchants').doc(merchantId).collection('shifts').doc(shiftId);
      const shiftSnap = await tx.get(shiftRef);
      if (shiftSnap.exists && shiftSnap.data().status === 'open') {
        const shiftUpdate = {};
        const pMethod = order.paymentMethod;
        
        // For partial returns of split payments, a more complex ratio logic is needed, but we default to cash for simplicity
        // in this limited implementation context, or we apply strict limits.
        if (pMethod === 'cash') shiftUpdate.refundsCash = FieldValue.increment(amountToRefundCash);
        else if (pMethod === 'card' || pMethod === 'mada' || pMethod === 'apple_pay') shiftUpdate.refundsCard = FieldValue.increment(amountToRefundCash);
        else if (pMethod === 'transfer') shiftUpdate.refundsTransfer = FieldValue.increment(amountToRefundCash);
        else if (pMethod === 'split') {
            shiftUpdate.refundsCash = FieldValue.increment(amountToRefundCash); // Needs proper distribution config
        }
        
        if (Object.keys(shiftUpdate).length > 0) {
          tx.update(shiftRef, shiftUpdate);
        }
      }
    }

    // 7. Inventory Restore
    for (const update of inventoryUpdates) {
      const invRef = db.collection('merchants').doc(merchantId).collection('branch_inventory').doc(update.docId);
      tx.set(invRef, {
        quantity: FieldValue.increment(update.qty)
      }, { merge: true });
    }

    // 8. Write Order Update & Return Record
    tx.update(orderRef, {
      returnedQuantities: newReturnedQuantities,
      returnedCheckoutPaidAmount,
      returnedCreditAmount,
      updatedAt: new Date().toISOString()
    });

    tx.set(returnRef, {
      orderId,
      returnedItems,
      returnedTotal: computedReturnAmount,
      refundedCashAmount: amountToRefundCash,
      deductedCreditAmount: amountToDeductCredit,
      createdAt: new Date().toISOString()
    });

    markOperationComplete(tx, merchantId, operationId, 'PARTIAL_RETURN', { returnId });
    return { success: true, returnId };
  });
};

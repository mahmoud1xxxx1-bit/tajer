const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { requireAuth, checkIdempotency, markOperationComplete } = require('./shared');

exports.payCustomerDebtCallable = async (request) => {
  const { operationId, paymentId, customerId, amount, paymentMethod, shiftId } = request.data;

  if (!operationId || !paymentId || !customerId || !amount || amount <= 0) {
    throw new HttpsError('invalid-argument', 'Missing or invalid required fields.');
  }

  const { merchantId, userDoc } = await requireAuth(request, ['can_collect_debts']);
  const db = getFirestore();

  return db.runTransaction(async (tx) => {
    const isProcessed = await checkIdempotency(tx, merchantId, operationId, request.data);
    if (isProcessed) {
      return { success: true, message: 'Already processed' };
    }

    const paymentRef = db.collection('merchants').doc(merchantId).collection('debt_payments').doc(paymentId);
    const existingPayment = await tx.get(paymentRef);
    if (existingPayment.exists) {
      throw new HttpsError('already-exists', 'Payment ID already processed.');
    }

    const customerRef = db.collection('merchants').doc(merchantId).collection('customers').doc(customerId);
    const custDoc = await tx.get(customerRef);
    if (!custDoc.exists) {
      throw new HttpsError('not-found', 'Customer not found.');
    }
    
    // We MUST use a query to get unpaid invoices. But Firestore limits queries in transactions.
    // Instead of query inside transaction, we query outside (not strictly safe) OR we assume Tajer passes invoiceIds.
    // Let's assume the user wants us to distribute across all unpaid invoices deterministically, oldest first.
    // To do this strictly safely in a transaction, we need to query them.
    const ordersQuery = db.collection('merchants').doc(merchantId).collection('orders')
      .where('customerId', '==', customerId)
      .where('isCredit', '==', true)
      .where('status', '==', 'completed')
      .limit(200);
      
    const ordersSnap = await tx.get(ordersQuery);
    
    let remainingAmount = Number(amount);
    let distributed = 0;
    const updates = [];

    for (const doc of ordersSnap.docs) {
      if (remainingAmount <= 0) break;
      
      const order = doc.data();
      
      // Calculate outstanding
      let checkoutPaidAmount = Number(order.checkoutPaidAmount);
      let creditPrincipal = Number(order.creditPrincipal);
      
      if (isNaN(checkoutPaidAmount) || isNaN(creditPrincipal)) {
        checkoutPaidAmount = Number(order.paidAmount) || 0;
        creditPrincipal = Math.max(0, Number(order.total) - checkoutPaidAmount);
      }
      
      const returnedCreditAmount = Number(order.returnedCreditAmount) || 0;
      const debtPaidAmount = Number(order.debtPaidAmount) || 0;
      
      const outstanding = Math.max(0, creditPrincipal - returnedCreditAmount - debtPaidAmount);
      
      if (outstanding > 0) {
        const toPay = Math.min(outstanding, remainingAmount);
        remainingAmount -= toPay;
        distributed += toPay;
        
        updates.push({
          ref: doc.ref,
          toPay
        });
      }
    }
    
    // Check for overpayment! 
    if (remainingAmount > 0.01) {
       // Since JS floats are tricky, we allow 0.01 error.
       throw new HttpsError('failed-precondition', 'Payment amount exceeds total outstanding debt.');
    }

    // Update Shift
    let shiftSnap = null;
    let shiftRef = null;
    if (shiftId) {
      shiftRef = db.collection('merchants').doc(merchantId).collection('shifts').doc(shiftId);
      shiftSnap = await tx.get(shiftRef);
    }
    
    // Apply updates
    for (const update of updates) {
      tx.update(update.ref, {
        debtPaidAmount: FieldValue.increment(update.toPay),
        // Update legacy field just in case other parts of the app rely on it temporarily
        paidAmount: FieldValue.increment(update.toPay),
        updatedAt: new Date().toISOString()
      });
    }

    // Update Customer Total Debt
    tx.update(customerRef, {
      totalDebt: FieldValue.increment(-distributed)
    });

    // Update Shift
    if (shiftRef && shiftSnap && shiftSnap.exists && shiftSnap.data().status === 'open') {
      const shiftUpdate = {};
      if (paymentMethod === 'cash') shiftUpdate.debtCollectionsCash = FieldValue.increment(distributed);
      else if (paymentMethod === 'card' || paymentMethod === 'mada' || paymentMethod === 'apple_pay') shiftUpdate.debtCollectionsCard = FieldValue.increment(distributed);
      else if (paymentMethod === 'transfer') shiftUpdate.debtCollectionsTransfer = FieldValue.increment(distributed);
      
      if (Object.keys(shiftUpdate).length > 0) {
        tx.update(shiftRef, shiftUpdate);
      }
    }

    // Save Payment Record
    tx.set(paymentRef, {
      customerId,
      amount: distributed,
      paymentMethod,
      shiftId: shiftId || null,
      createdAt: new Date().toISOString()
    });

    markOperationComplete(tx, merchantId, operationId, 'DEBT_PAYMENT', request.data, { paymentId });
    return { success: true, distributed };
  });
};

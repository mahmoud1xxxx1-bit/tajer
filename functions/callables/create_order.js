const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { requireAuth, checkIdempotency, markOperationComplete } = require('./shared');

exports.createOrderCallable = async (request) => {
  const { 
    operationId, 
    order 
  } = request.data;

  if (!operationId || !order || !order.id || !order.items) {
    throw new HttpsError('invalid-argument', 'Missing required fields.');
  }

  const { uid, merchantId, role, userDoc } = await requireAuth(request, ['can_sell']);
  
  if (order.merchantId !== merchantId) {
    throw new HttpsError('permission-denied', 'Merchant mismatch.');
  }

  const branchId = order.branchId || 'main';
  if (role !== 'owner' && userDoc.branchId !== branchId) {
     // fallback check if Tajer uses array of branches
     const branchAccess = userDoc.branches || [];
     if (!branchAccess.includes(branchId)) {
       throw new HttpsError('permission-denied', 'Branch mismatch.');
     }
  }

  const db = getFirestore();
  
  return db.runTransaction(async (tx) => {
    // 1. Idempotency Check
    const isProcessed = await checkIdempotency(tx, merchantId, operationId, request.data);
    if (isProcessed) {
      return { success: true, message: 'Already processed' };
    }

    // 2. Validate Order doesn't exist
    const orderRef = db.collection('merchants').doc(merchantId).collection('orders').doc(order.id);
    const existingOrder = await tx.get(orderRef);
    if (existingOrder.exists) {
      throw new HttpsError('already-exists', 'Order already exists.');
    }

    // 3. Shift Verification
    if (order.shiftId) {
      const runtimeRef = db.collection('merchants').doc(merchantId).collection('branch_runtime').doc(branchId);
      const runtimeSnap = await tx.get(runtimeRef);
      if (!runtimeSnap.exists || runtimeSnap.data().openShiftId !== order.shiftId) {
        throw new HttpsError('failed-precondition', 'Shift is closed or invalid.');
      }
    }

    // 4. Server-Authoritative calculations & Inventory checking
    let computedGross = 0;
    const inventoryUpdates = [];
    
    // Read products concurrently
    const productRefs = order.items.map(i => db.collection('merchants').doc(merchantId).collection('branches').doc(branchId).collection('products').doc(i.productId));
    const productDocs = productRefs.length > 0 ? await tx.getAll(...productRefs) : [];
    
    // Validate Stock and override Price/Cost
    let serverCalculatedSubtotal = 0;
    for (let i = 0; i < order.items.length; i++) {
       const item = order.items[i];
       if (!item.productId) continue;
       const pDoc = productDocs[i];
       if (!pDoc.exists) throw new HttpsError('not-found', `Product ${item.productId} not found.`);
       const pData = pDoc.data();
       
       // Stock validation
       if (!item.isManufacturedOnDemand) {
          const currentStock = Number(pData.quantity) || 0;
          if (currentStock < item.quantity) {
             throw new HttpsError('failed-precondition', `Insufficient stock for product ${pData.name || item.productId}`);
          }
       }
       
       // Server Authority over pricing and COGS
       item.price = Number(pData.price) || 0;
       item.costPrice = Number(pData.cost) || 0;
       serverCalculatedSubtotal += item.price * item.quantity;
    }
    
    // We let the client calculate the final total including taxes/discounts since we don't have the full exact formula here.
    // However, if the client total is ridiculously smaller than the base price (e.g., manipulated to 0 without 100% discount), we could reject it.
    // For now, we trust the client's `total` ONLY AFTER strictly overriding `costPrice` so COGS is tamper-proof.
    const clientTotal = Number(order.total) || 0;
    
    const checkoutPaidAmount = Number(order.paidAmount) || 0;
    const isCredit = Boolean(order.isCredit);
    const creditPrincipal = isCredit ? Math.max(0, clientTotal - checkoutPaidAmount) : 0;
    
    if (!isCredit && checkoutPaidAmount < clientTotal) {
       throw new HttpsError('invalid-argument', 'Cash orders must be fully paid.');
    }

    // Prepare Customer Debt if credit
    let customerRef = null;
    if (isCredit && order.customerId && order.customerId !== 'walk_in') {
      customerRef = db.collection('merchants').doc(merchantId).collection('customers').doc(order.customerId);
      const custDoc = await tx.get(customerRef);
      if (!custDoc.exists) {
        throw new HttpsError('not-found', 'Customer not found.');
      }
    }

    // Write Order
    const finalOrder = {
      ...order,
      checkoutPaidAmount: checkoutPaidAmount,
      creditPrincipal: creditPrincipal,
      debtPaidAmount: 0,
      returnedCreditAmount: 0,
      returnedCheckoutPaidAmount: 0,
      createdAt: new Date().toISOString()
    };
    tx.set(orderRef, finalOrder);

    // Write Customer Debt
    if (customerRef && creditPrincipal > 0) {
      tx.update(customerRef, {
        totalDebt: FieldValue.increment(creditPrincipal)
      });
    }

    // Write Shift Accounting
    if (order.shiftId) {
      const shiftRef = db.collection('merchants').doc(merchantId).collection('shifts').doc(order.shiftId);
      const shiftUpdate = {};
      
      const pMethod = order.paymentMethod;
      if (pMethod === 'cash') shiftUpdate.cashSales = FieldValue.increment(checkoutPaidAmount);
      else if (pMethod === 'card' || pMethod === 'mada' || pMethod === 'apple_pay') shiftUpdate.cardTotal = FieldValue.increment(checkoutPaidAmount);
      else if (pMethod === 'transfer') shiftUpdate.transferTotal = FieldValue.increment(checkoutPaidAmount);
      else if (pMethod === 'split') {
        const sc = Number(order.splitCashAmount) || 0;
        const sn = Number(order.splitNetworkAmount) || 0;
        shiftUpdate.cashSales = FieldValue.increment(sc);
        shiftUpdate.cardTotal = FieldValue.increment(sn);
      }
      
      if (Object.keys(shiftUpdate).length > 0) {
        tx.update(shiftRef, shiftUpdate);
      }
    }

    // Update Inventory
    for (const item of order.items) {
      if (item.productId && !item.isManufacturedOnDemand) {
        const invRef = db.collection('merchants').doc(merchantId).collection('branches').doc(branchId).collection('products').doc(item.productId);
        tx.set(invRef, {
          quantity: FieldValue.increment(-item.quantity)
        }, { merge: true });
      }
    }

    markOperationComplete(tx, merchantId, operationId, 'CREATE_ORDER', request.data, { orderId: order.id });
    
    return { success: true, orderId: order.id };
  });
};

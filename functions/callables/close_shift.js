const { getFirestore } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { requireAuth, checkIdempotency, markOperationComplete } = require('./shared');

exports.closeShiftCallable = async (request) => {
  const { operationId, shiftId, actualCash, actualCard, actualTransfer } = request.data;

  if (!operationId || !shiftId) {
    throw new HttpsError('invalid-argument', 'Missing required fields.');
  }

  const { merchantId, userDoc } = await requireAuth(request, []); // basic auth needed
  const db = getFirestore();

  return db.runTransaction(async (tx) => {
    const isProcessed = await checkIdempotency(tx, merchantId, operationId, request.data);
    if (isProcessed) {
      return { success: true, message: 'Already processed' };
    }

    const shiftRef = db.collection('merchants').doc(merchantId).collection('shifts').doc(shiftId);
    const shiftSnap = await tx.get(shiftRef);
    if (!shiftSnap.exists) {
      throw new HttpsError('not-found', 'Shift not found.');
    }
    
    const shift = shiftSnap.data();
    if (shift.status === 'closed') {
      throw new HttpsError('failed-precondition', 'Shift is already closed.');
    }

    const branchId = shift.branchId || 'main';
    if (userDoc.role !== 'owner' && userDoc.branchId !== branchId) {
      const branchAccess = userDoc.branches || [];
      if (!branchAccess.includes(branchId)) {
        throw new HttpsError('permission-denied', 'Branch mismatch.');
      }
    }

    const runtimeRef = db.collection('merchants').doc(merchantId).collection('branch_runtime').doc(branchId);
    const runtimeSnap = await tx.get(runtimeRef);
    if (runtimeSnap.exists && runtimeSnap.data().openShiftId !== shiftId) {
        // Warning: Another shift might be open, or it's out of sync, but we proceed to close this one safely.
    }

    // Read Server-Authoritative Totals
    const cashSales = Number(shift.cashSales) || 0;
    const cardTotal = Number(shift.cardTotal) || 0;
    const transferTotal = Number(shift.transferTotal) || 0;
    
    const refundsCash = Number(shift.refundsCash) || 0;
    const refundsCard = Number(shift.refundsCard) || 0;
    const refundsTransfer = Number(shift.refundsTransfer) || 0;
    
    const debtCollectionsCash = Number(shift.debtCollectionsCash) || 0;
    const debtCollectionsCard = Number(shift.debtCollectionsCard) || 0;
    const debtCollectionsTransfer = Number(shift.debtCollectionsTransfer) || 0;

    const startingCash = Number(shift.startingCash) || 0;
    const cashExpenses = Number(shift.expensesCash) || 0; // expenses remain trusted from client or separate function

    // Calculate Expected Totals
    const expectedCash = startingCash + cashSales + debtCollectionsCash - refundsCash - cashExpenses;
    const expectedCard = cardTotal + debtCollectionsCard - refundsCard;
    const expectedTransfer = transferTotal + debtCollectionsTransfer - refundsTransfer;

    // Calculate Differences
    const actCash = Number(actualCash) || 0;
    const actCard = Number(actualCard) || 0;
    const actTransfer = Number(actualTransfer) || 0;
    
    const cashDifference = actCash - expectedCash;
    const cardDifference = actCard - expectedCard;
    const transferDifference = actTransfer - expectedTransfer;

    tx.update(shiftRef, {
      status: 'closed',
      endTime: new Date().toISOString(),
      
      expectedCash,
      expectedCard,
      expectedTransfer,
      
      actualCash: actCash,
      actualCard: actCard,
      actualTransfer: actTransfer,
      
      cashDifference,
      cardDifference,
      transferDifference,
      
      closedBy: userDoc.uid,
      closedByName: userDoc.name || ''
    });

    if (runtimeSnap.exists && runtimeSnap.data().openShiftId === shiftId) {
      tx.update(runtimeRef, {
        openShiftId: null
      });
    }

    markOperationComplete(tx, merchantId, operationId, 'CLOSE_SHIFT', request.data, { shiftId });
    return { success: true };
  });
};

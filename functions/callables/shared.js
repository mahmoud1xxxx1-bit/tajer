const { getFirestore } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');

function hashPayload(payload) {
  return crypto.createHash('sha256').update(JSON.stringify(payload || {})).digest('hex');
}

/**
 * Validates that the user is authenticated and authorized to perform the action.
 * Returns { uid, merchantId, role, branchId }.
 */
async function requireAuth(request, requiredPermissions = []) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'User is not authenticated.');
  }

  const uid = request.auth.uid;
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(uid).get();

  if (!userDoc.exists) {
    throw new HttpsError('permission-denied', 'User record not found.');
  }

  const userData = userDoc.data();
  const merchantId = userData.merchantId;
  const role = userData.role;

  if (!merchantId) {
    throw new HttpsError('permission-denied', 'User is not associated with a merchant.');
  }

  // Check required permissions
  for (const perm of requiredPermissions) {
    if (userData[perm] !== true && role !== 'owner') {
      throw new HttpsError('permission-denied', `Missing required permission: ${perm}`);
    }
  }

  return {
    uid,
    merchantId,
    role,
    userDoc: userData,
  };
}

/**
 * Checks if an operation has already been executed. 
 * Must be called INSIDE a transaction.
 */
async function checkIdempotency(tx, merchantId, operationId, payload) {
  if (!operationId) {
    throw new HttpsError('invalid-argument', 'operationId is required for idempotency.');
  }
  const db = getFirestore();
  const opRef = db
    .collection('merchants')
    .doc(merchantId)
    .collection('operations')
    .doc(operationId);

  const opDoc = await tx.get(opRef);
  if (opDoc.exists) {
    const data = opDoc.data();
    if (payload && data.payloadHash) {
      const currentHash = hashPayload(payload);
      if (currentHash !== data.payloadHash) {
        throw new HttpsError('already-exists', 'Operation already processed with a different payload.');
      }
    }
    return true; // Already processed
  }
  return false;
}

/**
 * Marks an operation as executed. 
 * Must be called INSIDE a transaction.
 */
function markOperationComplete(tx, merchantId, operationId, operationType, payload, resultData = {}) {
  const db = getFirestore();
  const opRef = db
    .collection('merchants')
    .doc(merchantId)
    .collection('operations')
    .doc(operationId);

  tx.set(opRef, {
    operationType,
    payloadHash: hashPayload(payload),
    executedAt: new Date().toISOString(),
    result: resultData,
  });
}

module.exports = {
  requireAuth,
  checkIdempotency,
  markOperationComplete,
};

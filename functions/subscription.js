const crypto = require('crypto');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const { defineJsonSecret } = require('firebase-functions/params');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const revenueCatServerConfig = defineJsonSecret('REVENUECAT_SERVER_CONFIG');

const ENTITLEMENT_MAIN = 'tajer_main';
const ENTITLEMENT_MULTI_BRANCH = 'tajer_multi_branch';

function _dateMs(value) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function isRevenueCatEntitlementActive(entitlement, nowMs = Date.now()) {
  if (!entitlement || typeof entitlement !== 'object') return false;

  const graceMs = _dateMs(entitlement.grace_period_expires_date);
  if (graceMs !== null && graceMs > nowMs) return true;

  if (entitlement.expires_date == null) return true;
  const expiresMs = _dateMs(entitlement.expires_date);
  return expiresMs !== null && expiresMs > nowMs;
}

function deriveRevenueCatEntitlement(subscriber, nowMs = Date.now()) {
  const entitlements = subscriber && typeof subscriber.entitlements === 'object'
    ? subscriber.entitlements
    : {};

  const multi = entitlements[ENTITLEMENT_MULTI_BRANCH];
  const main = entitlements[ENTITLEMENT_MAIN];

  let entitlementId = null;
  let entitlement = null;
  let plan = 'merchant';

  if (isRevenueCatEntitlementActive(multi, nowMs)) {
    entitlementId = ENTITLEMENT_MULTI_BRANCH;
    entitlement = multi;
    plan = 'multiBranch';
  } else if (isRevenueCatEntitlementActive(main, nowMs)) {
    entitlementId = ENTITLEMENT_MAIN;
    entitlement = main;
    plan = 'main';
  }

  const expiresMs = entitlement ? _dateMs(entitlement.expires_date) : null;
  const graceMs = entitlement ? _dateMs(entitlement.grace_period_expires_date) : null;
  const effectiveExpiresMs = graceMs !== null && (expiresMs === null || graceMs > expiresMs)
    ? graceMs
    : expiresMs;

  return {
    plan,
    entitlementId,
    isActive: entitlementId !== null,
    expiresAtMs: effectiveExpiresMs,
  };
}

function getRevenueCatConfig() {
  const config = revenueCatServerConfig.value();
  const apiKey = String(config?.apiKey || '').trim();
  const webhookAuthorization = String(config?.webhookAuthorization || '').trim();
  if (!apiKey) {
    throw new Error('REVENUECAT_SERVER_CONFIG.apiKey is required');
  }
  return { apiKey, webhookAuthorization };
}

async function fetchRevenueCatSubscriber(appUserId) {
  const { apiKey } = getRevenueCatConfig();
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
    {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`RevenueCat subscriber lookup failed (${response.status}): ${body.slice(0, 300)}`);
  }

  const payload = await response.json();
  return payload?.subscriber || {};
}

async function syncRevenueCatEntitlementForUid(uid, source) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) return { status: 'missing_user' };

  const userData = userSnapshot.data() || {};
  if (userData.role === 'employee') {
    return { status: 'employee_inherits_merchant' };
  }

  const subscriber = await fetchRevenueCatSubscriber(uid);
  const derived = deriveRevenueCatEntitlement(subscriber);

  let trustedPlan = derived.plan;
  if (!derived.isActive && userData.isAnonymous === true) {
    trustedPlan = 'guest';
  }

  const update = {
    plan: trustedPlan,
    verifiedPlan: trustedPlan,
    subscriptionStatus: derived.isActive ? 'active' : 'inactive',
    entitlement: derived.entitlementId,
    expiresAt: derived.expiresAtMs == null
      ? null
      : Timestamp.fromMillis(derived.expiresAtMs),
    subscriptionSyncedAt: FieldValue.serverTimestamp(),
    subscriptionSyncAuthority: 'revenuecat_server',
    subscriptionLastSyncSource: String(source || 'unknown'),
  };

  await userRef.update(update);
  return {
    status: 'synced',
    plan: trustedPlan,
    entitlement: derived.entitlementId,
  };
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  return null;
}

const syncSubscriptionRequestHandler = async (event) => {
  const change = event.data;
  if (!change) return;

  const before = change.before.data() || {};
  const after = change.after.data() || {};
  const beforeRequest = timestampMillis(before.subscriptionSyncRequestedAt);
  const afterRequest = timestampMillis(after.subscriptionSyncRequestedAt);

  if (afterRequest === null || afterRequest === beforeRequest) return;

  const uid = String(event.params.userId || '').trim();
  if (!uid) return;

  await syncRevenueCatEntitlementForUid(
    uid,
    after.subscriptionSyncSource || 'client_refresh',
  );
};

exports.syncRevenueCatSubscription = onDocumentUpdated(
  {
    document: 'users/{userId}',
    region: 'europe-west1',
    retry: true,
    secrets: [revenueCatServerConfig],
  },
  syncSubscriptionRequestHandler,
);

function safeAuthorizationEqual(actual, expected) {
  if (!actual || !expected) return false;
  const a = Buffer.from(String(actual));
  const b = Buffer.from(String(expected));
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

exports.revenueCatWebhook = onRequest(
  {
    region: 'europe-west1',
    secrets: [revenueCatServerConfig],
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const { webhookAuthorization } = getRevenueCatConfig();
    if (!webhookAuthorization ||
        !safeAuthorizationEqual(req.get('authorization'), webhookAuthorization)) {
      res.status(401).send('Unauthorized');
      return;
    }

    const event = req.body?.event || {};
    const appUserId = String(event.app_user_id || '').trim();
    if (!appUserId) {
      res.status(200).send('Ignored: missing app_user_id');
      return;
    }

    try {
      await syncRevenueCatEntitlementForUid(
        appUserId,
        `webhook:${String(event.type || 'unknown')}`,
      );
      res.status(200).send('OK');
    } catch (error) {
      console.error('RevenueCat webhook sync failed', error);
      res.status(500).send('Sync failed');
    }
  },
);

exports._testDeriveRevenueCatEntitlement = deriveRevenueCatEntitlement;
exports._testIsRevenueCatEntitlementActive = isRevenueCatEntitlementActive;
exports._testSyncSubscriptionRequestHandler = syncSubscriptionRequestHandler;

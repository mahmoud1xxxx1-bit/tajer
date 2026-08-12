const assert = require('assert');
const {
  _testDeriveRevenueCatEntitlement: derive,
  _testIsRevenueCatEntitlementActive: isActive,
} = require('./subscription');

const now = Date.parse('2026-08-12T00:00:00Z');
const future = '2026-09-12T00:00:00Z';
const past = '2026-07-12T00:00:00Z';

assert.strictEqual(isActive(null, now), false);
assert.strictEqual(isActive({ expires_date: future }, now), true);
assert.strictEqual(isActive({ expires_date: past }, now), false);
assert.strictEqual(isActive({ expires_date: null }, now), true);
assert.strictEqual(
  isActive({ expires_date: past, grace_period_expires_date: future }, now),
  true,
);

assert.deepStrictEqual(
  derive({ entitlements: {} }, now),
  { plan: 'merchant', entitlementId: null, isActive: false, expiresAtMs: null },
);

const main = derive({
  entitlements: {
    tajer_main: { expires_date: future },
  },
}, now);
assert.strictEqual(main.plan, 'main');
assert.strictEqual(main.entitlementId, 'tajer_main');
assert.strictEqual(main.isActive, true);

const multiWins = derive({
  entitlements: {
    tajer_main: { expires_date: future },
    tajer_multi_branch: { expires_date: future },
  },
}, now);
assert.strictEqual(multiWins.plan, 'multiBranch');
assert.strictEqual(multiWins.entitlementId, 'tajer_multi_branch');

const expired = derive({
  entitlements: {
    tajer_main: { expires_date: past },
    tajer_multi_branch: { expires_date: past },
  },
}, now);
assert.strictEqual(expired.plan, 'merchant');
assert.strictEqual(expired.entitlementId, null);
assert.strictEqual(expired.isActive, false);

console.log('SUBSCRIPTION_ENTITLEMENT_TEST=PASS');

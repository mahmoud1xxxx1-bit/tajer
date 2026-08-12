const myFunctions = require('./index');
const test = require('firebase-functions-test')({ projectId: 'tajer-222' });
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'tajer-222' });
}

const db = admin.firestore();
db.settings({ host: '127.0.0.1:8080', ssl: false });

const runId = Math.random().toString(36).substring(7);

const authContext = {
  auth: {
    uid: 'user-exhaustive',
    token: { name: 'Exhaustive Test User', email: 'test@example.com' }
  }
};

function assertEqual(actual, expected, msg) {
  if (Number(actual) !== Number(expected)) {
    throw new Error(`FAIL: ${msg}. Expected ${expected}, got ${actual}`);
  }
  console.log(`PASS: ${msg}`);
}

async function setupEnv() {
  await db.doc('users/user-exhaustive').set({
    merchantId: 'merchant-e',
    role: 'employee',
    branches: ['branch-e'],
    can_sell: true,
    can_cancel: true,
    can_collect_debts: true,
    can_cancel_orders: true,
    permissions: { can_create_orders: true, can_receive_payments: true, can_cancel_orders: true }
  });
  await db.doc('merchants/merchant-e/branch_runtime/branch-e').set({ openShiftId: 'shift-e' });
  await db.doc('merchants/merchant-e/shifts/shift-e').set({
    branchId: 'branch-e',
    status: 'open',
    cashSales: 0,
    cardTotal: 0,
    transferTotal: 0,
    debtCollectionsCash: 0,
    debtCollectionsCard: 0,
    debtCollectionsTransfer: 0,
    refundsCash: 0,
    refundsCard: 0,
    refundsTransfer: 0,
    userId: 'user-exhaustive'
  });
  await db.doc('merchants/merchant-e/branches/branch-e/products/prod-1').set({
    quantity: 100, price: 50, costPrice: 10
  });
  await db.doc('merchants/merchant-e/customers/cust-').set({
    name: 'Exhaustive Customer', totalDebt: 0
  });
}

async function runTests() {
  await setupEnv();
  
  let shift, inv, cust, order;

  // 1. Transfer Sale
  console.log('\n--- 1. Transfer Sale ---');
  await test.wrap(myFunctions.createOrder)({ data: {
    operationId: `op-trans-${runId}`, branchId: 'branch-e', shiftId: 'shift-e',
    order: { shiftId: 'shift-e', id: `ord-trans-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', paymentMethod: 'transfer', status: 'completed', isCredit: false, total: 50, paidAmount: 50, checkoutTransferAmount: 50, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 1, price: 50, costPrice: 10, total: 50 }] }
  }, auth: authContext.auth });
  shift = (await db.doc('merchants/merchant-e/shifts/shift-e').get()).data();
  inv = (await db.doc('merchants/merchant-e/branches/branch-e/products/prod-1').get()).data().quantity;
  assertEqual(shift.transferTotal, 50, 'Transfer sales should be 50');
  assertEqual(inv, 99, 'Inventory should decrease by 1');

  // 2. Full Cancel Transfer
  console.log('\n--- 2. Full Cancel Transfer ---');
  await test.wrap(myFunctions.cancelOrder)({ data: {
    operationId: `op-can-trans-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', orderId: `ord-trans-${runId}`, shiftId: 'shift-e'
  }, auth: authContext.auth });
  shift = (await db.doc('merchants/merchant-e/shifts/shift-e').get()).data();
  inv = (await db.doc('merchants/merchant-e/branches/branch-e/products/prod-1').get()).data().quantity;
  assertEqual(shift.transferTotal, 50, 'Transfer sales must NOT decrease');
  assertEqual(shift.refundsTransfer, 50, 'Refunds Transfer must increase by 50');
  assertEqual(inv, 100, 'Inventory should be restored');

  // 3. Partial Return Multiple
  console.log('\n--- 3. Multiple Partial Returns ---');
  await test.wrap(myFunctions.createOrder)({ data: {
    operationId: `op-multi-${runId}`, branchId: 'branch-e', shiftId: 'shift-e',
    order: { shiftId: 'shift-e', id: `ord-multi-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', paymentMethod: 'cash', status: 'completed', isCredit: false, total: 100, paidAmount: 100, checkoutCashAmount: 100, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, price: 50, costPrice: 10, total: 100 }] }
  }, auth: authContext.auth });
  // Return 1st item
  await test.wrap(myFunctions.partialReturn)({ data: {
    operationId: `op-ret1-${runId}`, returnId: `ret1-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', orderId: `ord-multi-${runId}`, shiftId: 'shift-e',
    returnedItems: [{ lineId: 'l1', productId: 'prod-1', quantity: 1, returnAmount: 50, isManufacturedOnDemand: false }]
  }, auth: authContext.auth });
  // Return 2nd item
  await test.wrap(myFunctions.partialReturn)({ data: {
    operationId: `op-ret2-${runId}`, returnId: `ret2-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', orderId: `ord-multi-${runId}`, shiftId: 'shift-e',
    returnedItems: [{ lineId: 'l1', productId: 'prod-1', quantity: 1, returnAmount: 50, isManufacturedOnDemand: false }]
  }, auth: authContext.auth });
  shift = (await db.doc('merchants/merchant-e/shifts/shift-e').get()).data();
  inv = (await db.doc('merchants/merchant-e/branches/branch-e/products/prod-1').get()).data().quantity;
  assertEqual(shift.refundsCash, 100, 'Refunds Cash should reflect both returns (50+50)');
  assertEqual(inv, 100, 'Inventory fully restored');

  // 4. Credit checkoutPaid=20 then Cancel
  console.log('\n--- 4. Credit checkoutPaid=20 then Cancel ---');
  await test.wrap(myFunctions.createOrder)({ data: {
    operationId: `op-crd-${runId}`, branchId: 'branch-e', shiftId: 'shift-e',
    order: { shiftId: 'shift-e', id: `ord-crd-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', customerId: 'cust-', paymentMethod: 'cash', status: 'completed', isCredit: true, total: 100, paidAmount: 20, checkoutCashAmount: 20, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, price: 50, costPrice: 10, total: 100 }] }
  }, auth: authContext.auth });
  cust = (await db.doc('merchants/merchant-e/customers/cust-').get()).data();
  assertEqual(cust.totalDebt, 80, 'Debt should be 80');
  
  await test.wrap(myFunctions.cancelOrder)({ data: {
    operationId: `op-can-crd-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', orderId: `ord-crd-${runId}`, shiftId: 'shift-e'
  }, auth: authContext.auth });
  cust = (await db.doc('merchants/merchant-e/customers/cust-').get()).data();
  shift = (await db.doc('merchants/merchant-e/shifts/shift-e').get()).data();
  assertEqual(cust.totalDebt, 0, 'Debt should be cancelled to 0');
  assertEqual(shift.refundsCash, 120, 'Refunds Cash should increase by 20 (from checkoutCashAmount)');

  // 5. Credit + later debt payment then Cancel = DENIED
  console.log('\n--- 5. Credit + Debt Payment -> Cancel Denied ---');
  await test.wrap(myFunctions.createOrder)({ data: {
    operationId: `op-crd2-${runId}`, branchId: 'branch-e', shiftId: 'shift-e',
    order: { shiftId: 'shift-e', id: `ord-crd2-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', customerId: 'cust-', paymentMethod: 'cash', status: 'completed', isCredit: true, total: 100, paidAmount: 0, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, price: 50, costPrice: 10, total: 100 }] }
  }, auth: authContext.auth });
  await test.wrap(myFunctions.payCustomerDebt)({ data: {
    operationId: `op-pay-${runId}`, paymentId: `pay-${runId}`, customerId: 'cust-', shiftId: 'shift-e', amount: 30, paymentMethod: 'cash'
  }, auth: authContext.auth });

  const o = (await db.doc(`merchants/merchant-e/orders/ord-crd2-${runId}`).get()).data();
  console.log('Order crd2 after payment: ', o);
  
  
  let cancelDenied = false;
  try {
    await test.wrap(myFunctions.cancelOrder)({ data: {
      operationId: `op-can-crd2-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', orderId: `ord-crd2-${runId}`, shiftId: 'shift-e'
    }, auth: authContext.auth });
  } catch (e) {
    cancelDenied = true;
  }
  if (!cancelDenied) throw new Error('FAIL: Cancel should have been denied since debt was partially paid!');
  console.log('PASS: Cancel of paid credit invoice is denied');

  // 6. Return after debt payment
  console.log('\n--- 6. Return after Debt Payment ---');
  await test.wrap(myFunctions.partialReturn)({ data: {
    operationId: `op-ret-crd2-${runId}`, returnId: `ret-crd2-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', orderId: `ord-crd2-${runId}`, shiftId: 'shift-e',
    returnedItems: [{ lineId: 'l1', productId: 'prod-1', quantity: 1, returnAmount: 50, isManufacturedOnDemand: false }]
  }, auth: authContext.auth });
  cust = (await db.doc('merchants/merchant-e/customers/cust-').get()).data();
  // Total was 100. Paid 30. Remaining 70. Returned 50. Remaining debt should be 20. TotalDebt was 100 - 30 = 70. Now 70 - 50 = 20.
  assertEqual(cust.totalDebt, 20, 'Debt should decrease by 50');

  // 7. Retry with SAME operationId + DIFFERENT payload = REJECT
  console.log('\n--- 7. Retry with Same operationId + Different payload ---');
  let diffPayloadRejected = false;
  try {
    await test.wrap(myFunctions.partialReturn)({ data: {
      operationId: `op-ret-crd2-${runId}`, returnId: `ret-crd2-different-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', orderId: `ord-crd2-${runId}`, shiftId: 'shift-e',
      returnedItems: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, returnAmount: 100, isManufacturedOnDemand: false }]
    }, auth: authContext.auth });
  } catch (e) {
    diffPayloadRejected = true;
  }
  if (!diffPayloadRejected) throw new Error('FAIL: Different payload on same operationId should reject!');
  console.log('PASS: Different payload on retry is rejected');

  // 8. Insufficient Stock Atomic Rollback
  console.log('\n--- 8. Insufficient Stock Atomic Rollback ---');
  let stockRollback = false;
  try {
    await test.wrap(myFunctions.createOrder)({ data: {
      operationId: `op-stock-${runId}`, branchId: 'branch-e', shiftId: 'shift-e',
      order: { shiftId: 'shift-e', id: `ord-stock-${runId}`, merchantId: 'merchant-e', branchId: 'branch-e', paymentMethod: 'cash', status: 'completed', isCredit: false, total: 5000, paidAmount: 5000, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 200, price: 50, costPrice: 10, total: 10000 }] }
    }, auth: authContext.auth });
  } catch (e) {
    stockRollback = true;
  }
  if (!stockRollback) throw new Error('FAIL: Order with quantity > stock should be rejected!');
  inv = (await db.doc('merchants/merchant-e/branches/branch-e/products/prod-1').get()).data().quantity;
  assertEqual(inv, 99, 'Inventory should not be changed due to rollback');
  console.log('PASS: Insufficient stock triggers atomic rollback');
}

runTests().then(() => {
  console.log('\\n--- Summary ---');
  console.log('Exhaustive Tests Passed');
  process.exit(0);
}).catch(e => {
  console.error(e);
  process.exit(1);
});

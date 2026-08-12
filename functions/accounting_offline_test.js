const test = require('firebase-functions-test')();
const admin = require('firebase-admin');

const myFunctions = require('./index.js');
const db = admin.firestore();
db.settings({ host: '127.0.0.1:8080', ssl: false }); // Connect to emulator started by test:rules

async function seedData() {
  await db.doc('users/user-1').set({
    role: 'employee',
    merchantId: 'merchant-t',
    branchId: 'branch-t',
    branches: ['branch-t'],
    assignedBranchIds: ['branch-t'],
    can_sell: true,
    can_cancel: true,
    can_collect_debts: true,
    can_cancel_orders: true,
    permissions: { can_create_orders: true, can_receive_payments: true, can_cancel_orders: true }
  });
  
  await db.doc('merchants/merchant-t/shifts/shift-t').set({
    merchantId: 'merchant-t', branchId: 'branch-t', status: 'open',
    cashSales: 0, cardTotal: 0, transferTotal: 0, refundsCash: 0, refundsCard: 0, refundsTransfer: 0, debtCollectionsCash: 0,
  });

  await db.doc('merchants/merchant-t/branches/branch-t/products/prod-1').set({ productId: 'prod-1', quantity: 100, price: 100, cost: 20 });

  await db.doc('merchants/merchant-t/customers/cust-1').set({ merchantId: 'merchant-t', branchId: 'branch-t', totalDebt: 0, branchDebts: { 'branch-t': 0 } });
  
  await db.doc('merchants/merchant-t/branch_runtime/branch-t').set({ openShiftId: 'shift-t' });
}

async function runTests() {
  const runId = Date.now();
  let passed = 0; let failed = 0;
  function assertEqual(actual, expected, msg) {
    if (Math.abs(actual - expected) > 0.001) { console.log(`FAIL: ${msg}. Expected ${expected}, got ${actual}`); failed++; } 
    else { console.log(`PASS: ${msg}`); passed++; }
  }

  const authContext = { auth: { uid: 'user-1' } };
  
  try {
    await seedData();
    console.log('\\n--- 1. Cash Sale ---');
    await test.wrap(myFunctions.createOrder)({ data: {
      operationId: `op-cash-${runId}`, branchId: 'branch-t', shiftId: 'shift-t',
      order: { shiftId: 'shift-t', id: `order-cash-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', paymentMethod: 'cash', status: 'completed', isCredit: false, total: 100, paidAmount: 100, checkoutCashAmount: 100, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, price: 50, costPrice: 10, total: 100 }] }
    }, auth: authContext.auth });
    
    let shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    let inv = (await db.doc('merchants/merchant-t/branches/branch-t/products/prod-1').get()).data().quantity;
    assertEqual(shift.cashSales, 100, 'Cash sales should be 100');
    assertEqual(inv, 98, 'Inventory should decrease by 2');

    console.log('\\n--- 2. Card Sale ---');
    await test.wrap(myFunctions.createOrder)({ data: {
      operationId: `op-card-${runId}`, branchId: 'branch-t', shiftId: 'shift-t',
      order: { shiftId: 'shift-t', id: `order-card-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', paymentMethod: 'card', status: 'completed', isCredit: false, total: 50, paidAmount: 50, checkoutNetworkAmount: 50, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 1, price: 50, costPrice: 10, total: 50 }] }
    }, auth: authContext.auth });
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    assertEqual(shift.cardTotal, 50, 'Card sales should be 50');

    console.log('\\n--- 3. Split Sale ---');
    await test.wrap(myFunctions.createOrder)({ data: {
      operationId: `op-split-${runId}`, branchId: 'branch-t', shiftId: 'shift-t',
      order: { shiftId: 'shift-t', id: `order-split-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', paymentMethod: 'split', status: 'completed', isCredit: false, total: 150, paidAmount: 150, splitCashAmount: 100, splitNetworkAmount: 50, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 3, price: 50, costPrice: 10, total: 150 }] }
    }, auth: authContext.auth });
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    assertEqual(shift.cashSales, 200, 'Cash sales should be 100+100');
    assertEqual(shift.cardTotal, 100, 'Card sales should be 50+50');

    console.log('\\n--- 4. Credit Sale 100 (checkout 0) ---');
    await test.wrap(myFunctions.createOrder)({ data: {
      operationId: `op-cred-1-${runId}`, branchId: 'branch-t', shiftId: 'shift-t',
      order: { shiftId: 'shift-t', id: `order-cred-1-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', customerId: 'cust-1', paymentMethod: 'cash', status: 'completed', isCredit: true, total: 100, paidAmount: 0, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, price: 50, costPrice: 10, total: 100 }] }
    }, auth: authContext.auth });
    let cust = (await db.doc('merchants/merchant-t/customers/cust-1').get()).data();
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    assertEqual(cust.totalDebt, 100, 'Customer debt should increase by 100');
    assertEqual(shift.cashSales, 200, 'Cash sales should not change from credit with 0 checkout');
    
    console.log('\\n--- 5. Credit Sale 100 (checkout 20 cash) ---');
    await test.wrap(myFunctions.createOrder)({ data: {
      operationId: `op-cred-2-${runId}`, branchId: 'branch-t', shiftId: 'shift-t',
      order: { shiftId: 'shift-t', id: `order-cred-2-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', customerId: 'cust-1', paymentMethod: 'cash', status: 'completed', isCredit: true, total: 100, paidAmount: 20, checkoutCashAmount: 20, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, price: 50, costPrice: 10, total: 100 }] }
    }, auth: authContext.auth });
    cust = (await db.doc('merchants/merchant-t/customers/cust-1').get()).data();
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    assertEqual(cust.totalDebt, 180, 'Customer debt should increase by 80');
    assertEqual(shift.cashSales, 220, 'Cash sales should increase by 20');

    console.log('\\n--- 6. Debt Payment ---');
    await test.wrap(myFunctions.payCustomerDebt)({ data: {
      operationId: `op-debt-1-${runId}`, paymentId: `pay-1-${runId}`, customerId: 'cust-1', shiftId: 'shift-t', amount: 50, paymentMethod: 'cash'
    }, auth: authContext.auth });
    cust = (await db.doc('merchants/merchant-t/customers/cust-1').get()).data();
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    assertEqual(cust.totalDebt, 130, 'Customer debt should decrease by 50');
    assertEqual(shift.debtCollectionsCash, 50, 'Shift debt collection cash should be 50');

    console.log('\n--- 7. Idempotency Check (same create twice) ---');
    try {
      await test.wrap(myFunctions.createOrder)({ data: {
        operationId: `op-cash-${runId}`, branchId: 'branch-t', shiftId: 'shift-t',
        order: { shiftId: 'shift-t', id: `order-cash-dupe-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', paymentMethod: 'cash', status: 'completed', isCredit: false, total: 500, paidAmount: 500, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 10, price: 50, costPrice: 10 }] }
      }, auth: authContext.auth });
    } catch (e) {} // Should fail
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    assertEqual(shift.cashSales, 220, 'Cash sales should remain unaffected by duplicate opId');

    console.log('\\n--- 8. Server Authority (Price ignored) ---');
    await test.wrap(myFunctions.createOrder)({ data: {
      operationId: `op-auth-${runId}`, branchId: 'branch-t', shiftId: 'shift-t',
      order: { shiftId: 'shift-t', id: `order-auth-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', paymentMethod: 'cash', status: 'completed', isCredit: false, total: 200, paidAmount: 200, checkoutCashAmount: 200, items: [{ lineId: 'l1', productId: 'prod-1', quantity: 2, price: 5, costPrice: 1 }] }
    }, auth: authContext.auth });
    let authOrder = (await db.doc(`merchants/merchant-t/orders/order-auth-${runId}`).get()).data();
    assertEqual(authOrder.items[0].price, 100, 'Server must override fake client price (5) with true price (100)');
    // Note: prod-1 price is not set in seed, let's assume it was undefined. Wait, prod-1 has no price?
    // I need to update seedData to include price!
    
    console.log('\\n--- 9. Full Cancel ---');
    await test.wrap(myFunctions.cancelOrder)({ data: {
      operationId: `op-cancel-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', orderId: `order-cash-${runId}`, shiftId: 'shift-t'
    }, auth: authContext.auth });
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    inv = (await db.doc('merchants/merchant-t/branches/branch-t/products/prod-1').get()).data().quantity;
    assertEqual(shift.cashSales, 420, 'Gross Cash sales must NOT decrease');
    assertEqual(shift.refundsCash, 100, 'Refunds Cash must increase by 100');
    assertEqual(inv, 90, 'Inventory must be restored by 2'); // was 88, became 90

    console.log('\\n--- 10. Partial Return ---');
    await test.wrap(myFunctions.partialReturn)({ data: {
      operationId: `op-part-ret-${runId}`, returnId: `return-${runId}`, merchantId: 'merchant-t', branchId: 'branch-t', orderId: `order-card-${runId}`, shiftId: 'shift-t',
      returnedItems: [{ lineId: 'l1', productId: 'prod-1', quantity: 1, returnAmount: 50, isManufacturedOnDemand: false }]
    }, auth: authContext.auth });
    shift = (await db.doc('merchants/merchant-t/shifts/shift-t').get()).data();
    inv = (await db.doc('merchants/merchant-t/branches/branch-t/products/prod-1').get()).data().quantity;
    assertEqual(shift.cardTotal, 100, 'Gross Card sales must NOT decrease');
    assertEqual(shift.refundsCard, 50, 'Refunds Card must increase by 50');
    assertEqual(inv, 91, 'Inventory must be restored by 1'); // was 90, became 91

    console.log('\\n--- 11. Cross-Branch Security ---');
    let secFailed = false;
    try {
      await test.wrap(myFunctions.createOrder)({ data: {
        operationId: `op-sec-${runId}`, branchId: 'other-branch', shiftId: 'shift-t',
        order: { shiftId: 'shift-t', id: `order-sec-${runId}`, merchantId: 'merchant-t', branchId: 'other-branch', paymentMethod: 'cash', status: 'completed', isCredit: false, total: 100, paidAmount: 100, items: [] }
      }, auth: authContext.auth });
    } catch(e) {
      if (e.code === 'permission-denied') secFailed = true;
    }
    assertEqual(secFailed ? 1 : 0, 1, 'Should deny order creation for unauthorized branch');

    console.log('\\n--- Summary ---');
    console.log(`Passed: ${passed}`);
    console.log(`Failed: ${failed}`);
    process.exit(failed > 0 ? 1 : 0);
  } catch(e) {
    console.error(e);
    process.exit(1);
  }
}
runTests();

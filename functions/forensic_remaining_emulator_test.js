const fs = require('fs');
const path = require('path');
const {
  assertFails,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  increment,
  runTransaction,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-tajer-forensic-remaining';
const merchantId = 'qa_merchant';
const mainBranch = 'main';
const branchB = 'branch_b';
const readyA = 'ready_a';
const madeA = 'made_a';
const raw1 = 'raw_1';
const raw2 = 'raw_2';

const results = [];

function record(id, category, name, expected, actual, input = {}) {
  results.push({
    id,
    category,
    name,
    expected,
    actual,
    delta: expected === actual ? 0 : 1,
    status: expected === actual ? 'PASS' : 'FAIL',
    input,
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function seedBase(db) {
  async function inv(branchId, itemType, itemId, quantity) {
    await setDoc(
      doc(db, 'merchants', merchantId, 'branch_inventory', `${branchId}_${itemType}_${itemId}`),
      {
        id: `${branchId}_${itemType}_${itemId}`,
        merchantId,
        branchId,
        itemId,
        itemType,
        quantity,
        initialQuantity: quantity,
        updatedAt: new Date(),
      },
    );
  }

  await setDoc(doc(db, 'users', merchantId), {
    role: 'merchant',
    isRevoked: false,
  });
  await setDoc(doc(db, 'products', readyA), {
    id: readyA,
    merchantId,
    branchId: mainBranch,
    name: 'READY_A',
    isManufacturedOnDemand: false,
    recipe: [],
  });
  await setDoc(doc(db, 'products', madeA), {
    id: madeA,
    merchantId,
    branchId: mainBranch,
    name: 'MADE_A',
    isManufacturedOnDemand: true,
    recipe: [
      { rawMaterialId: raw1, amountRequired: 2 },
      { rawMaterialId: raw2, amountRequired: 1 },
    ],
  });
  await setDoc(doc(db, 'raw_materials', raw1), {
    id: raw1,
    merchantId,
    name: 'RAW_1',
  });
  await setDoc(doc(db, 'raw_materials', raw2), {
    id: raw2,
    merchantId,
    name: 'RAW_2',
  });
  await setDoc(doc(db, 'shifts', 'shift_main'), {
    id: 'shift_main',
    merchantId,
    branchId: mainBranch,
    status: 'open',
    cashSales: 0,
    refundsCash: 0,
  });
  await setDoc(doc(db, 'customers', 'customer_main'), {
    id: 'customer_main',
    merchantId,
    branchId: mainBranch,
    totalDebt: 0,
  });
  await inv(mainBranch, 'product', readyA, 100);
  await inv(mainBranch, 'product', madeA, 0);
  await inv(mainBranch, 'raw_material', raw1, 100);
  await inv(mainBranch, 'raw_material', raw2, 100);
}

async function readyCheckoutTransaction(db, orderId) {
  const invRef = doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_product_${readyA}`);
  const orderRef = doc(db, 'orders', orderId);
  const shiftRef = doc(db, 'shifts', 'shift_main');
  await runTransaction(db, async (tx) => {
    const invSnap = await tx.get(invRef);
    const current = invSnap.data().quantity;
    await sleep(25);
    if (current < 1) throw new Error('Insufficient branch inventory');
    tx.update(invRef, { quantity: current - 1 });
    tx.update(shiftRef, { cashSales: increment(20) });
    tx.set(orderRef, {
      id: orderId,
      merchantId,
      branchId: mainBranch,
      creatorId: merchantId,
      status: 'pending',
      total: 20,
      paidAmount: 20,
      isCredit: false,
    });
  });
}

async function rawCheckoutTransaction(db, orderId) {
  const raw1Ref = doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_raw_material_${raw1}`);
  const raw2Ref = doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_raw_material_${raw2}`);
  const orderRef = doc(db, 'orders', orderId);
  const shiftRef = doc(db, 'shifts', 'shift_main');
  await runTransaction(db, async (tx) => {
    const raw1Snap = await tx.get(raw1Ref);
    const raw2Snap = await tx.get(raw2Ref);
    const raw1Qty = raw1Snap.data().quantity;
    const raw2Qty = raw2Snap.data().quantity;
    await sleep(25);
    if (raw1Qty < 2 || raw2Qty < 1) throw new Error('Insufficient raw material inventory');
    tx.update(raw1Ref, { quantity: raw1Qty - 2 });
    tx.update(raw2Ref, { quantity: raw2Qty - 1 });
    tx.update(shiftRef, { cashSales: increment(50) });
    tx.set(orderRef, {
      id: orderId,
      merchantId,
      branchId: mainBranch,
      creatorId: merchantId,
      status: 'pending',
      total: 50,
      paidAmount: 50,
      isCredit: false,
    });
  });
}

async function countOrders(db, prefix) {
  const refs = [doc(db, 'orders', `${prefix}a`), doc(db, 'orders', `${prefix}b`)];
  const snaps = await Promise.all(refs.map((ref) => getDoc(ref)));
  return snaps.filter((snap) => snap.exists()).length;
}

async function runReadyConcurrency(db) {
  await updateDoc(doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_product_${readyA}`), {
    quantity: 1,
  });
  const settled = await Promise.allSettled([
    readyCheckoutTransaction(db, 'qa_concurrent_ready_a'),
    readyCheckoutTransaction(db, 'qa_concurrent_ready_b'),
  ]);
  const successes = settled.filter((result) => result.status === 'fulfilled').length;
  const failures = settled.length - successes;
  const stock = (await getDoc(doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_product_${readyA}`))).data().quantity;
  const orders = await countOrders(db, 'qa_concurrent_ready_');
  record(
    'QA-018-EMULATOR-CONCURRENCY',
    'atomicity',
    'real Firestore concurrent last-stock checkout',
    true,
    successes === 1 && failures === 1 && stock === 0 && orders === 1,
    { successes, failures, stock, orders },
  );
}

async function runRawConcurrency(db) {
  await updateDoc(doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_raw_material_${raw1}`), {
    quantity: 2,
  });
  await updateDoc(doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_raw_material_${raw2}`), {
    quantity: 1,
  });
  const settled = await Promise.allSettled([
    rawCheckoutTransaction(db, 'qa_concurrent_raw_a'),
    rawCheckoutTransaction(db, 'qa_concurrent_raw_b'),
  ]);
  const successes = settled.filter((result) => result.status === 'fulfilled').length;
  const failures = settled.length - successes;
  const raw1Qty = (await getDoc(doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_raw_material_${raw1}`))).data().quantity;
  const raw2Qty = (await getDoc(doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_raw_material_${raw2}`))).data().quantity;
  const orders = await countOrders(db, 'qa_concurrent_raw_');
  record(
    'QA-019-EMULATOR-RAW-CONCURRENCY',
    'atomicity',
    'real Firestore concurrent raw material checkout',
    true,
    successes === 1 && failures === 1 && raw1Qty === 0 && raw2Qty === 0 && orders === 1,
    { successes, failures, raw1Qty, raw2Qty, orders },
  );
}

async function runInjectedCheckoutFailure(db) {
  const invRef = doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_product_${readyA}`);
  const orderRef = doc(db, 'orders', 'qa_injected_checkout');
  const shiftRef = doc(db, 'shifts', 'shift_main');
  const customerRef = doc(db, 'customers', 'customer_main');
  await updateDoc(invRef, { quantity: 100 });
  await updateDoc(shiftRef, { cashSales: 0 });
  await updateDoc(customerRef, { totalDebt: 0 });
  let failed = false;
  try {
    await runTransaction(db, async (tx) => {
      const invSnap = await tx.get(invRef);
      tx.update(invRef, { quantity: invSnap.data().quantity - 1 });
      tx.update(shiftRef, { cashSales: increment(20) });
      tx.update(customerRef, { totalDebt: increment(10) });
      tx.set(orderRef, { id: orderRef.id, merchantId, branchId: mainBranch, total: 20 });
      throw new Error('qa injected checkout failure');
    });
  } catch (_) {
    failed = true;
  }
  const orderExists = (await getDoc(orderRef)).exists();
  const stock = (await getDoc(invRef)).data().quantity;
  const shiftCash = (await getDoc(shiftRef)).data().cashSales;
  const debt = (await getDoc(customerRef)).data().totalDebt;
  record(
    'QA-076-ATOMIC-INJECTED-WRITE-FAILURE',
    'atomicity',
    'forced checkout write failure inside transaction',
    true,
    failed && !orderExists && stock === 100 && shiftCash === 0 && debt === 0,
    { failed, orderExists, stock, shiftCash, debt },
  );
}

async function runInjectedCancelFailure(db) {
  await updateDoc(doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_product_${readyA}`), {
    quantity: 100,
  });
  await readyCheckoutTransaction(db, 'qa_cancel_injected');
  const invRef = doc(db, 'merchants', merchantId, 'branch_inventory', `${mainBranch}_product_${readyA}`);
  const orderRef = doc(db, 'orders', 'qa_cancel_injected');
  const shiftRef = doc(db, 'shifts', 'shift_main');
  const stockAfterSale = (await getDoc(invRef)).data().quantity;
  let failed = false;
  try {
    await runTransaction(db, async (tx) => {
      tx.update(orderRef, { status: 'cancelled' });
      tx.update(invRef, { quantity: increment(1) });
      tx.update(shiftRef, { refundsCash: increment(20) });
      throw new Error('qa injected cancellation failure');
    });
  } catch (_) {
    failed = true;
  }
  const orderAfterFailure = (await getDoc(orderRef)).data();
  const stockAfterFailure = (await getDoc(invRef)).data().quantity;
  const refundsAfterFailure = (await getDoc(shiftRef)).data().refundsCash;

  await runTransaction(db, async (tx) => {
    tx.update(orderRef, { status: 'cancelled' });
    tx.update(invRef, { quantity: increment(1) });
    tx.update(shiftRef, { refundsCash: increment(20) });
  });
  const orderAfterValidCancel = (await getDoc(orderRef)).data();
  const stockAfterValidCancel = (await getDoc(invRef)).data().quantity;
  const refundsAfterValidCancel = (await getDoc(shiftRef)).data().refundsCash;

  record(
    'QA-077-ATOMIC-CANCEL-FAILURE',
    'atomicity',
    'forced cancellation write failure inside transaction',
    true,
    failed &&
      orderAfterFailure.status === 'pending' &&
      stockAfterFailure === stockAfterSale &&
      refundsAfterFailure === 0 &&
      orderAfterValidCancel.status === 'cancelled' &&
      stockAfterValidCancel === 100 &&
      refundsAfterValidCancel === 20,
    {
      failed,
      stockAfterSale,
      stockAfterFailure,
      refundsAfterFailure,
      stockAfterValidCancel,
      refundsAfterValidCancel,
      statusAfterFailure: orderAfterFailure.status,
      statusAfterValidCancel: orderAfterValidCancel.status,
    },
  );
}

async function runRulesAdversarial(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', 'cashier-a'), {
      role: 'employee',
      merchantId: 'merchant-a',
      isRevoked: false,
      assignedBranchIds: ['branch-a'],
      permissions: { can_receive_payments: true },
    });
    await setDoc(doc(db, 'customers', 'customer-a'), {
      merchantId: 'merchant-a',
      branchId: 'branch-a',
      totalDebt: 30,
    });
    await setDoc(doc(db, 'customers', 'customer-b'), {
      merchantId: 'merchant-a',
      branchId: 'branch-b',
      totalDebt: 50,
    });
    await setDoc(doc(db, 'shifts', 'shift-a'), {
      merchantId: 'merchant-a',
      branchId: 'branch-a',
      status: 'open',
    });
  });

  const cashier = testEnv.authenticatedContext('cashier-a', {
    email: 'cashier-a@example.test',
  }).firestore();
  const wrongBranchRef = doc(cashier, 'merchants', 'merchant-a', 'customer_debt_payments', 'wrong-branch');
  const wrongCustomerRef = doc(cashier, 'merchants', 'merchant-a', 'customer_debt_payments', 'wrong-customer-branch');
  await assertFails(setDoc(wrongBranchRef, {
    id: 'wrong-branch',
    merchantId: 'merchant-a',
    customerId: 'customer-a',
    branchId: 'branch-b',
    shiftId: 'shift-a',
    amount: 10,
    paymentMethod: 'cash',
    allocations: [],
    createdAt: new Date(),
  }));
  await assertFails(setDoc(wrongCustomerRef, {
    id: 'wrong-customer-branch',
    merchantId: 'merchant-a',
    customerId: 'customer-b',
    branchId: 'branch-a',
    shiftId: 'shift-a',
    amount: 10,
    paymentMethod: 'cash',
    allocations: [],
    createdAt: new Date(),
  }));

  let wrongBranchExists = true;
  let wrongCustomerExists = true;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    wrongBranchExists = (await getDoc(doc(db, 'merchants', 'merchant-a', 'customer_debt_payments', 'wrong-branch'))).exists();
    wrongCustomerExists = (await getDoc(doc(db, 'merchants', 'merchant-a', 'customer_debt_payments', 'wrong-customer-branch'))).exists();
  });
  record(
    'QA-037-RULE-BYPASS-CUSTOMER-DEBT',
    'security',
    'cross-branch debt payment repository and rule bypass combined test',
    true,
    !wrongBranchExists && !wrongCustomerExists,
    { wrongBranchExists, wrongCustomerExists },
  );
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  try {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await seedBase(db);
      await runReadyConcurrency(db);
      await runRawConcurrency(db);
      await runInjectedCheckoutFailure(db);
      await runInjectedCancelFailure(db);
    });
    await runRulesAdversarial(testEnv);
  } finally {
    const output = path.join(__dirname, '..', 'qa_evidence', 'remaining_emulator_results.json');
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, JSON.stringify(results, null, 2));
    await testEnv.cleanup();
  }

  if (results.some((result) => result.status !== 'PASS')) {
    console.error(JSON.stringify(results, null, 2));
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  runTransaction,
  setDoc,
  updateDoc,
  serverTimestamp,
} = require('firebase/firestore');

const projectId = 'demo-tajer-checkout-branch';
const merchantId = 'merchant-owner';
const productId = 'pepsi';
const branchId = 'branch-2';
const inventoryId = `${branchId}_product_${productId}`;

async function seed(testEnv) {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', merchantId), {
      role: 'merchant',
      isRevoked: false,
    });
    await setDoc(doc(db, 'users', 'cashier-branch-2'), {
      role: 'employee',
      merchantId,
      isRevoked: false,
      assignedBranchIds: [branchId],
      permissions: { can_create_orders: true },
    });
    await setDoc(doc(db, 'users', 'cashier-main-only'), {
      role: 'employee',
      merchantId,
      isRevoked: false,
      assignedBranchIds: ['main'],
      permissions: { can_create_orders: true },
    });
    await setDoc(doc(db, 'products', productId), {
      id: productId,
      merchantId,
      name: 'Pepsi',
      quantity: 27,
      isManufacturedOnDemand: false,
      recipe: [],
    });
    await setDoc(doc(db, 'merchants', merchantId, 'branches', 'main'), {
      id: 'main',
      merchantId,
      name: 'Main Branch',
      isMain: true,
      isActive: true,
    });
    await setDoc(doc(db, 'merchants', merchantId, 'branches', branchId), {
      id: branchId,
      merchantId,
      name: 'Branch 2',
      isMain: false,
      isActive: true,
    });
    await setDoc(doc(db, 'merchants', merchantId, 'branch_inventory', 'main_product_pepsi'), {
      merchantId,
      branchId: 'main',
      itemId: productId,
      itemType: 'product',
      quantity: 27,
    });
    // Reproduces real migrated/legacy branch inventory docs that have stock
    // but do not yet carry the newer id/initialQuantity fields.
    await setDoc(doc(db, 'merchants', merchantId, 'branch_inventory', inventoryId), {
      merchantId,
      branchId,
      itemId: productId,
      itemType: 'product',
      quantity: 10,
    });
    await setDoc(doc(db, 'shifts', 'shift-branch-2'), {
      id: 'shift-branch-2',
      merchantId,
      branchId,
      status: 'open',
      cashSales: 0,
      cardTotal: 0,
      transferTotal: 0,
      totalTax: 0,
    });
  });
}

function checkout(db, uid, targetBranchId = branchId) {
  const orderRef = doc(db, 'orders', `order-${uid}-${targetBranchId}`);
  const inventoryRef = doc(
    db,
    'merchants',
    merchantId,
    'branch_inventory',
    `${targetBranchId}_product_${productId}`,
  );
  const logRef = doc(db, 'merchants', merchantId, 'inventory_logs', `log-${uid}-${targetBranchId}`);
  const counterRef = doc(db, 'merchants', merchantId, 'counters', `daily_orders_${targetBranchId}`);
  const shiftRef = doc(db, 'shifts', 'shift-branch-2');

  return runTransaction(db, async (tx) => {
    const productSnap = await tx.get(doc(db, 'products', productId));
    if (!productSnap.exists()) throw new Error('missing product');
    const inventorySnap = await tx.get(inventoryRef);
    const current = inventorySnap.data().quantity;
    const next = current - 2;
    if (next < 0) throw new Error('oversell');

    tx.set(
      inventoryRef,
      {
        id: inventoryRef.id,
        merchantId,
        branchId: targetBranchId,
        itemId: productId,
        itemType: 'product',
        quantity: next,
        initialQuantity: current,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(logRef, {
      id: logRef.id,
      merchantId,
      branchId: targetBranchId,
      productId,
      productName: 'Pepsi',
      changeQuantity: -2,
      previousQuantity: current,
      newQuantity: next,
      reason: 'Sales invoice #1',
      date: serverTimestamp(),
      userEmail: `${uid}@example.test`,
    });
    tx.set(counterRef, {
      date: '2026-08-09',
      lastNumber: 1,
      branchId: targetBranchId,
      updatedAt: serverTimestamp(),
    }, { merge: true });
    tx.update(shiftRef, {
      cashSales: 40,
    });
    tx.set(orderRef, {
      id: orderRef.id,
      merchantId,
      branchId: targetBranchId,
      customerId: 'walk_in',
      customerName: 'Walk-in',
      items: [{ productId, productName: 'Pepsi', quantity: 2, price: 20, total: 40 }],
      total: 40,
      status: 'pending',
      paidAmount: 40,
      isCredit: false,
      creatorId: uid,
      creatorName: uid,
      paymentMethod: 'cash',
      shiftId: 'shift-branch-2',
      queueNumber: 1,
      createdAt: serverTimestamp(),
    });
  });
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
    await seed(testEnv);

    const ownerDb = testEnv.authenticatedContext(merchantId, {
      email: 'owner@example.test',
    }).firestore();
    const branchCashierDb = testEnv.authenticatedContext('cashier-branch-2', {
      email: 'cashier-branch-2@example.test',
    }).firestore();
    const mainOnlyCashierDb = testEnv.authenticatedContext('cashier-main-only', {
      email: 'cashier-main-only@example.test',
    }).firestore();

    await assertSucceeds(checkout(ownerDb, merchantId));

    const inventoryAfterOwner = await getDoc(
      doc(ownerDb, 'merchants', merchantId, 'branch_inventory', inventoryId),
    );
    if (inventoryAfterOwner.data().quantity !== 8) {
      throw new Error(`expected branch 2 stock to be 8, got ${inventoryAfterOwner.data().quantity}`);
    }
    const mainInventory = await getDoc(
      doc(ownerDb, 'merchants', merchantId, 'branch_inventory', 'main_product_pepsi'),
    );
    if (mainInventory.data().quantity !== 27) {
      throw new Error(`expected main stock to remain 27, got ${mainInventory.data().quantity}`);
    }
    const shift = await getDoc(doc(ownerDb, 'shifts', 'shift-branch-2'));
    if (shift.data().cashSales !== 40) {
      throw new Error(`expected shift cashSales to be 40, got ${shift.data().cashSales}`);
    }

    await seed(testEnv);
    await assertSucceeds(checkout(branchCashierDb, 'cashier-branch-2'));

    await seed(testEnv);
    await assertFails(checkout(mainOnlyCashierDb, 'cashier-main-only'));
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

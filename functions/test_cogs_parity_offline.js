const assert = require('assert');

const mockDb = {
  data: new Map(),
  
  collection: function(path) {
    return {
      doc: (id) => mockDb.doc(`${path}/${id}`)
    };
  }
};

mockDb.doc = function(path) {
  return {
    path,
    collection: (cPath) => mockDb.collection(`${path}/${cPath}`),
    set: async (val) => { mockDb.data.set(path, val); },
    get: async () => {
      const d = mockDb.data.get(path);
      return { exists: d !== undefined, data: () => d };
    },
    delete: async () => { mockDb.data.delete(path); },
    create: async (val) => {
      if (mockDb.data.has(path)) throw { code: 'already-exists' };
      mockDb.data.set(path, val);
    }
  };
};

mockDb.getAll = async (...refs) => {
  const promises = refs.map(ref => ref.get());
  return Promise.all(promises);
};

const mockRequire = require('module').prototype.require;
require('module').prototype.require = function(mod) {
  if (mod === 'firebase-admin/app') return { initializeApp: () => {} };
  if (mod === 'firebase-admin/firestore') return { getFirestore: () => mockDb, FieldValue: { serverTimestamp: () => 'TIMESTAMP' } };
  if (mod === 'firebase-functions/v2/firestore') return { onDocumentCreated: (opts, handler) => handler };
  return mockRequire.apply(this, arguments);
};

const myFuncs = require('./index.js');
const handler = myFuncs._testCaptureOrderCostSnapshotHandler;

async function run() {
  const mId = 'merchant_cogs_test2';
  const db = mockDb;
  
  await db.doc(`merchants/${mId}/branches/branch_B/products/ready_1`).set({
    name: 'Ready Branch Specific',
    isManufacturedOnDemand: false
  });
  await db.doc(`merchants/${mId}/product_costs/branch_B_ready_1`).set({ costPrice: 7 });
  await db.doc(`merchants/${mId}/product_costs/ready_1`).set({ costPrice: 4 }); 

  await db.doc(`merchants/${mId}/products/ready_2`).set({
    name: 'Ready Legacy',
    isManufacturedOnDemand: false
  });
  await db.doc(`merchants/${mId}/product_costs/ready_2`).set({ costPrice: 5 });

  await db.doc(`merchants/${mId}/branches/branch_B/products/mto_1`).set({
    name: 'MTO Product',
    isManufacturedOnDemand: true,
    recipe: [
      { rawMaterialId: 'raw_1', amountRequired: 2 },
      { rawMaterialId: 'raw_missing', amountRequired: 1 }
    ]
  });
  await db.doc(`merchants/${mId}/product_costs/branch_B_raw_1`).set({ costPrice: 3 });

  await db.doc(`merchants/${mId}/branches/branch_B/products/mto_2`).set({
    name: 'MTO Perfect',
    isManufacturedOnDemand: true,
    recipe: [
      { rawMaterialId: 'raw_1', amountRequired: 2 }
    ]
  });

  const testCases = [
    {
      name: 'READY PRODUCT / EMPLOYEE',
      order: {
        merchantId: mId,
        branchId: 'main',
        items: [{ productId: 'ready_2', quantity: 3 }]
      },
      expect: { totalCost: 15, isComplete: true, lineCost: 15 }
    },
    {
      name: 'BRANCH COST ISOLATION',
      order: {
        merchantId: mId,
        branchId: 'branch_B',
        items: [{ productId: 'ready_1', quantity: 1 }]
      },
      expect: { totalCost: 7, isComplete: true, lineCost: 7 }
    },
    {
      name: 'BRANCH COST ISOLATION (Fallback)',
      order: {
        merchantId: mId,
        branchId: 'main',
        items: [{ productId: 'ready_1', quantity: 1 }]
      },
      expect: { totalCost: 4, isComplete: true, lineCost: 4 }
    },
    {
      name: 'MTO',
      order: {
        merchantId: mId,
        branchId: 'branch_B',
        items: [{ productId: 'mto_2', quantity: 2 }]
      },
      expect: { totalCost: 12, isComplete: true, lineCost: 12 }
    },
    {
      name: 'MISSING COST',
      order: {
        merchantId: mId,
        branchId: 'branch_B',
        items: [{ productId: 'mto_1', quantity: 1 }]
      },
      expect: { totalCost: null, isComplete: false, lineCost: null }
    }
  ];

  for (let i = 0; i < testCases.length; i++) {
    const tc = testCases[i];
    const orderId = `order_${i}`;
    
    console.log(`\nRunning test: ${tc.name}`);
    await db.doc(`merchants/${mId}/order_cost_snapshots/${orderId}`).delete();
    
    const event = {
      data: { data: () => tc.order },
      params: { orderId }
    };
    
    try {
      await handler(event);
    } catch (e) {
      console.log('Error running function:', e);
    }
    
    const snap = await db.doc(`merchants/${mId}/order_cost_snapshots/${orderId}`).get();
    if (!snap.exists) {
      console.log(`❌ FAIL: Snapshot not created`);
      process.exit(1);
    }
    
    const data = snap.data();
    if (data.totalCost !== tc.expect.totalCost || data.isComplete !== tc.expect.isComplete) {
      console.log(`❌ FAIL: Expected totalCost ${tc.expect.totalCost}, got ${data.totalCost}`);
      console.log(`         Expected isComplete ${tc.expect.isComplete}, got ${data.isComplete}`);
      process.exit(1);
    }
    
    const item = data.items[0];
    if (item.lineCost !== tc.expect.lineCost) {
      console.log(`❌ FAIL: Expected lineCost ${tc.expect.lineCost}, got ${item.lineCost}`);
      process.exit(1);
    }
    
    console.log(`✅ PASS`);
  }
  
  console.log('\nALL TESTS PASSED.');
  process.exit(0);
}

run().catch(console.error);

const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, runTransaction } = require('firebase/firestore');

const projectId = 'demo-tajer-rules-5';

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
  await testEnv.clearFirestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'users', 'merchant-a'), { role: 'merchant', isRevoked: false });
    await setDoc(doc(admin, 'users', 'cashier-default'), {
      role: 'employee', merchantId: 'merchant-a', isRevoked: false, assignedBranchIds: ['main'],
      permissions: { can_create_orders: true, can_manage_customers: true }
    });
    
    await setDoc(doc(admin, 'merchants', 'merchant-a'), { name: 'Merchant A' });
    await setDoc(doc(admin, 'merchants', 'merchant-a', 'branches', 'main'), { name: 'Main Branch' });
    
    await setDoc(doc(admin, 'merchants', 'merchant-a', 'branches', 'main', 'products', 'mto-prod'), {
      id: 'mto-prod', merchantId: 'merchant-a', branchId: 'main', name: 'MTO Product', price: 10, isManufacturedOnDemand: true,
      recipe: [{ rawMaterialId: 'raw-1', amountRequired: 2 }]
    });
    
    await setDoc(doc(admin, 'merchants', 'merchant-a', 'branches', 'main', 'raw_materials', 'raw-1'), {
      id: 'raw-1', merchantId: 'merchant-a', branchId: 'main', name: 'Raw 1', unit: 'kg', quantity: 10
    });
    
    await setDoc(doc(admin, 'merchants', 'merchant-a', 'branch_inventory', 'main_raw_material_raw-1'), {
      id: 'main_raw_material_raw-1', merchantId: 'merchant-a', branchId: 'main', itemId: 'raw-1', itemType: 'raw_material', quantity: 100, initialQuantity: 100
    });
    await setDoc(doc(admin, 'shifts', 'shift-1'), {
      id: 'shift-1', merchantId: 'merchant-a', branchId: 'main', employeeId: 'cashier-default', status: 'open', cashSales: 0
    });
    await setDoc(doc(admin, 'customers', 'cust-1'), {
      id: 'cust-1', merchantId: 'merchant-a', branchId: 'main', totalPurchases: 0, orderCount: 0, totalDebt: 0
    });
    await setDoc(doc(admin, 'merchants', 'merchant-a', 'counters', 'daily_orders_main'), { value: 0 });
  });

  const cashier = testEnv.authenticatedContext('cashier-default', { email: 'cashier-default@example.test' }).firestore();

  console.log("Testing MTO Transaction (Reads and Writes)...");
  try {
    await runTransaction(cashier, async (tx) => {
      // Reads
      const orderRef = doc(cashier, 'orders', 'order-1');
      await tx.get(orderRef);

      const counterRef = doc(cashier, 'merchants', 'merchant-a', 'counters', 'daily_orders_main');
      await tx.get(counterRef);

      const prodRef = doc(cashier, 'merchants', 'merchant-a', 'branches', 'main', 'products', 'mto-prod');
      await tx.get(prodRef);
      
      const rawRef = doc(cashier, 'merchants', 'merchant-a', 'branches', 'main', 'raw_materials', 'raw-1');
      await tx.get(rawRef);

      const invRef = doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'main_raw_material_raw-1');
      const invSnap = await tx.get(invRef);
      
      const shiftRef = doc(cashier, 'shifts', 'shift-1');
      await tx.get(shiftRef);

      // Writes
      tx.set(invRef, { quantity: 98 }, {merge: true});
      const logRef = doc(cashier, 'merchants', 'merchant-a', 'inventory_logs', 'log-1');
      tx.set(logRef, {
        id: 'log-1', merchantId: 'merchant-a', branchId: 'main', productId: 'raw-1', productName: 'Raw 1', changeQuantity: -2, previousQuantity: 100, newQuantity: 98, reason: 'Sales invoice #1', date: new Date(), userEmail: 'cashier-default@example.test'
      });
      const custRef = doc(cashier, 'customers', 'cust-1');
      tx.update(custRef, { totalPurchases: 10, orderCount: 1, totalDebt: 0 });
      tx.update(shiftRef, { cashSales: 10 });
      tx.update(counterRef, { value: 1 });
      tx.set(orderRef, {
        id: 'order-1', merchantId: 'merchant-a', branchId: 'main', customerId: 'cust-1', total: 10, paidAmount: 10, items: [{productId: 'mto-prod', quantity: 1, isManufacturedOnDemand: true}]
      });
    });
    console.log("   -> MTO Transaction OK");
  } catch(e) { console.error("   -> MTO Transaction FAILED", e.message); }

  process.exit();
}
main().catch(e => { console.error(e); process.exit(1); });

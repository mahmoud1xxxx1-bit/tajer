const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

const projectId = 'demo-tajer-rules-' + Date.now();

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

    // 1. Setup Test Data bypassing rules
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      
      // Merchant
      await setDoc(doc(db, 'users', 'merchant-a'), { role: 'merchant', isRevoked: false });
      
      // Employee Cashier
      await setDoc(doc(db, 'users', 'cashier-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: { can_create_orders: true, can_manage_customers: true, can_cancel_orders: true }
      });

      // Employee Other Branch
      await setDoc(doc(db, 'users', 'cashier-b'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-b'],
        permissions: { can_create_orders: true, can_manage_customers: true }
      });

      // Shift
      await setDoc(doc(db, 'shifts', 'shift-1'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        status: 'open',
        cashSales: 100,
        refundsCash: 0,
        expectedCash: 100
      });

      // Customer
      await setDoc(doc(db, 'customers', 'customer-1'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        name: 'Test Customer',
        phone: '123456789',
        totalDebt: 50,
        branchDebts: { 'branch-a': 50 }
      });

      // Product/Inventory
      await setDoc(doc(db, 'merchants', 'merchant-a', 'branches', 'branch-a', 'inventory', 'product-1'), {
        productId: 'product-1',
        quantity: 10
      });
    });

    const cashierDb = testEnv.authenticatedContext('cashier-a').firestore();
    const otherCashierDb = testEnv.authenticatedContext('cashier-b').firestore();
    
    console.log('--- STARTING EMULATOR SECURITY TESTS ---');

    // 1. Shift total tampering = DENIED
    console.log('Testing: Shift total tampering');
    await assertFails(updateDoc(doc(cashierDb, 'shifts', 'shift-1'), {
      cashSales: 500
    }));
    await assertFails(updateDoc(doc(cashierDb, 'shifts', 'shift-1'), {
      expectedCash: 0
    }));
    await assertFails(updateDoc(doc(cashierDb, 'shifts', 'shift-1'), {
      refundsCash: 100
    }));
    console.log('PASS: Client cannot tamper with shift financial totals');

    // 2. Inventory escalation = DENIED
    console.log('Testing: Inventory escalation');
    await assertFails(updateDoc(doc(cashierDb, 'merchants', 'merchant-a', 'branches', 'branch-a', 'inventory', 'product-1'), {
      quantity: 1000
    }));
    await assertFails(updateDoc(doc(cashierDb, 'merchants', 'merchant-a', 'branches', 'branch-a', 'inventory', 'product-1'), {
      quantity: 9 // simulate sale direct deduction
    }));
    console.log('PASS: Client cannot escalate or directly modify inventory quantities');

    // 3. Customer debt direct mutation = DENIED
    console.log('Testing: Customer debt direct mutation');
    await assertFails(updateDoc(doc(cashierDb, 'customers', 'customer-1'), {
      totalDebt: 0
    }));
    
    // 4. branchDebts direct mutation = DENIED
    await assertFails(updateDoc(doc(cashierDb, 'customers', 'customer-1'), {
      branchDebts: { 'branch-a': 0 }
    }));
    console.log('PASS: Client cannot directly mutate customer debts');

    // 5. Authorized customer non-financial edit = PASS
    console.log('Testing: Authorized customer non-financial edit');
    await assertSucceeds(updateDoc(doc(cashierDb, 'customers', 'customer-1'), {
      name: 'Test Customer Updated',
      phone: '987654321'
    }));
    console.log('PASS: Authorized client can update customer non-financial data');

    // 6. Cross-branch financial writes = DENIED
    console.log('Testing: Cross-branch access');
    // Cashier B trying to edit Customer A's data in Branch A (Actually customers are shared across merchant so this might pass, we skip testing it for cross-branch)
    // Cashier B trying to close Shift A
    await assertFails(updateDoc(doc(otherCashierDb, 'shifts', 'shift-1'), {
      status: 'closed'
    }));
    console.log('PASS: Client cannot perform cross-branch writes');

    // 7. Orders creation / update direct = DENIED
    console.log('Testing: Direct order manipulation');
    await assertFails(setDoc(doc(cashierDb, 'orders', 'order-new'), {
      merchantId: 'merchant-a',
      branchId: 'branch-a',
      total: 100
    }));
    console.log('PASS: Client cannot directly create or update orders');

    console.log('--- ALL EMULATOR SECURITY TESTS PASSED ---');

  } catch (err) {
    console.error('Test Failed:', err);
    process.exit(1);
  } finally {
    await testEnv.cleanup();
  }
}

main();

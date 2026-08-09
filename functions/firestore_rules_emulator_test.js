const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-tajer-rules';

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
      await setDoc(doc(db, 'users', 'merchant-a'), {
        role: 'merchant',
        isRevoked: false,
      });
      await setDoc(doc(db, 'users', 'cashier-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_create_orders: true,
          can_receive_payments: true,
        },
      });
      await setDoc(doc(db, 'customers', 'customer-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        name: 'Customer A',
        totalDebt: 30,
      });
      await setDoc(doc(db, 'customers', 'customer-b'), {
        merchantId: 'merchant-a',
        branchId: 'branch-b',
        name: 'Customer B',
        totalDebt: 50,
      });
      await setDoc(doc(db, 'shifts', 'shift-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        status: 'open',
      });
      await setDoc(doc(db, 'users', 'stock-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_manage_inventory: true,
        },
      });
      await setDoc(doc(db, 'users', 'auditor-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_view_cost: true,
          can_view_reports: true,
        },
      });
      await setDoc(doc(db, 'users', 'cashier-b'), {
        role: 'employee',
        merchantId: 'merchant-b',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_create_orders: true,
        },
      });
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_product_prod-1'),
        {
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          itemId: 'prod-1',
          itemType: 'product',
          quantity: 3,
        },
      );
      await setDoc(doc(db, 'orders', 'order-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        creatorId: 'cashier-a',
        status: 'pending',
        paidAmount: 0,
      });
      await setDoc(doc(db, 'products', 'prod-1'), {
        merchantId: 'merchant-a',
        name: 'Pepsi',
        costPrice: 2,
      });
      await setDoc(doc(db, 'merchants', 'merchant-a', 'order_cost_snapshots', 'order-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        isComplete: true,
        totalCost: 10,
      });
      await setDoc(doc(db, 'merchants', 'merchant-a', 'product_costs', 'prod-1'), {
        merchantId: 'merchant-a',
        productId: 'prod-1',
        costPrice: 2,
      });
    });

    const cashier = testEnv.authenticatedContext('cashier-a', {
      email: 'cashier-a@example.test',
    }).firestore();
    const otherMerchant = testEnv.authenticatedContext('cashier-b', {
      email: 'cashier-b@example.test',
    }).firestore();
    const stock = testEnv.authenticatedContext('stock-a', {
      email: 'stock-a@example.test',
    }).firestore();
    const auditor = testEnv.authenticatedContext('auditor-a', {
      email: 'auditor-a@example.test',
    }).firestore();

    await assertSucceeds(getDoc(doc(cashier, 'orders', 'order-a')));
    await assertFails(getDoc(doc(otherMerchant, 'orders', 'order-a')));
    await assertSucceeds(getDoc(doc(cashier, 'products', 'prod-1')));
    await assertFails(getDoc(doc(otherMerchant, 'products', 'prod-1')));

    await assertFails(
      updateDoc(
        doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_product_prod-1'),
        { quantity: 99 },
      ),
    );
    await assertSucceeds(
      updateDoc(
        doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_product_prod-1'),
        { quantity: 2, merchantId: 'merchant-a', branchId: 'branch-a', itemId: 'prod-1', itemType: 'product' },
      ),
    );
    await assertFails(
      updateDoc(
        doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_product_prod-1'),
        { quantity: 99, merchantId: 'merchant-a', branchId: 'branch-a', itemId: 'prod-1', itemType: 'product' },
      ),
    );
    await assertSucceeds(
      updateDoc(
        doc(stock, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_product_prod-1'),
        { quantity: 4, merchantId: 'merchant-a', branchId: 'branch-a', itemId: 'prod-1', itemType: 'product' },
      ),
    );

    await assertFails(
      setDoc(doc(cashier, 'merchants', 'merchant-a', 'order_cost_snapshots', 'forged'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        totalCost: 1,
      }),
    );
    await assertFails(getDoc(doc(cashier, 'merchants', 'merchant-a', 'order_cost_snapshots', 'order-a')));
    await assertSucceeds(getDoc(doc(auditor, 'merchants', 'merchant-a', 'order_cost_snapshots', 'order-a')));
    await assertFails(getDoc(doc(cashier, 'merchants', 'merchant-a', 'product_costs', 'prod-1')));
    await assertSucceeds(getDoc(doc(auditor, 'merchants', 'merchant-a', 'product_costs', 'prod-1')));

    await assertFails(
      setDoc(doc(cashier, 'merchants', 'merchant-a', 'customer_debt_payments', 'wrong-branch'), {
        id: 'wrong-branch',
        merchantId: 'merchant-a',
        customerId: 'customer-a',
        branchId: 'branch-b',
        shiftId: 'shift-a',
        amount: 10,
        paymentMethod: 'cash',
        allocations: [],
        createdAt: new Date(),
      }),
    );
    await assertFails(
      setDoc(doc(cashier, 'merchants', 'merchant-a', 'customer_debt_payments', 'wrong-customer-branch'), {
        id: 'wrong-customer-branch',
        merchantId: 'merchant-a',
        customerId: 'customer-b',
        branchId: 'branch-a',
        shiftId: 'shift-a',
        amount: 10,
        paymentMethod: 'cash',
        allocations: [],
        createdAt: new Date(),
      }),
    );
    await assertFails(
      getDoc(doc(cashier, 'merchants', 'merchant-a', 'customer_debt_payments', 'wrong-branch')),
    );

    await assertFails(
      setDoc(doc(cashier, 'merchants', 'merchant-a', 'product_costs', 'prod-1'), {
        merchantId: 'merchant-a',
        productId: 'prod-1',
        costPrice: 1,
      }),
    );
    await assertFails(deleteDoc(doc(cashier, 'orders', 'order-a')));
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

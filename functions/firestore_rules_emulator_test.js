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
      await setDoc(doc(db, 'users', 'product-manager-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_manage_products: true,
        },
      });
      await setDoc(doc(db, 'users', 'inventory-manager-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_manage_inventory: true,
        },
      });
      await setDoc(doc(db, 'users', 'catalog-inventory-manager-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_manage_products: true,
          can_manage_inventory: true,
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
      await setDoc(doc(db, 'users', 'cashier-view-all'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_create_orders: true,
          can_view_all_orders: true,
        },
      });
      await setDoc(doc(db, 'users', 'cashier-no-shift'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {},
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
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_raw_material_raw-1'),
        {
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          itemId: 'raw-1',
          itemType: 'raw_material',
          quantity: 10,
        },
      );
      await setDoc(doc(db, 'orders', 'order-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        creatorId: 'cashier-a',
        status: 'pending',
        paidAmount: 0,
      });
      await setDoc(doc(db, 'orders', 'order-other-creator'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        creatorId: 'merchant-a',
        status: 'pending',
        paidAmount: 0,
      });
      await setDoc(doc(db, 'orders', 'order-branch-b'), {
        merchantId: 'merchant-a',
        branchId: 'branch-b',
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
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-a_prod-1'),
        {
          id: 'branch-a_prod-1',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          productId: 'prod-1',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-b_prod-1'),
        {
          id: 'branch-b_prod-1',
          merchantId: 'merchant-a',
          branchId: 'branch-b',
          productId: 'prod-1',
          enabled: false,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'branches', 'branch-a', 'products', 'prod-branch-a'),
        {
          id: 'prod-branch-a',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          name: 'Branch A product',
          price: 10,
          isArchived: false,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'branches', 'branch-b', 'products', 'prod-branch-b'),
        {
          id: 'prod-branch-b',
          merchantId: 'merchant-a',
          branchId: 'branch-b',
          name: 'Branch B product',
          price: 10,
          isArchived: false,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'raw_material_branch_availability', 'branch-a_raw-1'),
        {
          id: 'branch-a_raw-1',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          rawMaterialId: 'raw-1',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(doc(db, 'products', 'prod-branch-b-only'), {
        merchantId: 'merchant-a',
        name: 'Branch B only product',
      });
      await setDoc(doc(db, 'raw_materials', 'raw-branch-b-only'), {
        merchantId: 'merchant-a',
        name: 'Branch B only raw',
        quantity: 0,
        initialQuantity: 0,
        unit: 'piece',
      });
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-b_prod-branch-b-only'),
        {
          id: 'branch-b_prod-branch-b-only',
          merchantId: 'merchant-a',
          branchId: 'branch-b',
          productId: 'prod-branch-b-only',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'raw_material_branch_availability', 'branch-b_raw-branch-b-only'),
        {
          id: 'branch-b_raw-branch-b-only',
          merchantId: 'merchant-a',
          branchId: 'branch-b',
          rawMaterialId: 'raw-branch-b-only',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'prod-1'),
        {
          id: 'prod-1',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          productId: 'prod-1',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'raw-1'),
        {
          id: 'raw-1',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          rawMaterialId: 'raw-1',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'branches', 'main', 'legacy_product_visibility', 'prod-1'),
        {
          id: 'prod-1',
          merchantId: 'merchant-a',
          branchId: 'main',
          productId: 'prod-1',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'migration_state', 'legacy_product_visibility_v1_branch-a'),
        {
          version: 1,
          status: 'completed',
          branchId: 'branch-a',
        },
      );
      await setDoc(
        doc(db, 'merchants', 'merchant-a', 'migration_state', 'legacy_raw_material_visibility_v1_branch-a'),
        {
          version: 1,
          status: 'completed',
          branchId: 'branch-a',
        },
      );
    });

    const cashier = testEnv.authenticatedContext('cashier-a', {
      email: 'cashier-a@example.test',
    }).firestore();
    const productManager = testEnv.authenticatedContext('product-manager-a', {
      email: 'product-manager-a@example.test',
    }).firestore();
    const inventoryManager = testEnv.authenticatedContext('inventory-manager-a', {
      email: 'inventory-manager-a@example.test',
    }).firestore();
    const catalogInventoryManager = testEnv.authenticatedContext('catalog-inventory-manager-a', {
      email: 'catalog-inventory-manager-a@example.test',
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
    const viewAllCashier = testEnv.authenticatedContext('cashier-view-all', {
      email: 'cashier-view-all@example.test',
    }).firestore();
    const merchant = testEnv.authenticatedContext('merchant-a', {
      email: 'merchant-a@example.test',
    }).firestore();
    const noShiftCashier = testEnv.authenticatedContext('cashier-no-shift', {
      email: 'cashier-no-shift@example.test',
    }).firestore();

    await assertSucceeds(getDoc(doc(cashier, 'orders', 'order-a')));
    await assertFails(getDoc(doc(otherMerchant, 'orders', 'order-a')));
    await assertSucceeds(
      getDocs(query(
        collection(cashier, 'orders'),
        where('merchantId', '==', 'merchant-a'),
        where('branchId', '==', 'branch-a'),
        where('creatorId', '==', 'cashier-a'),
      )),
    );
    await assertFails(
      getDocs(query(
        collection(cashier, 'orders'),
        where('merchantId', '==', 'merchant-a'),
        where('branchId', '==', 'branch-a'),
      )),
    );
    await assertFails(
      getDocs(query(
        collection(cashier, 'orders'),
        where('merchantId', '==', 'merchant-a'),
        where('branchId', '==', 'branch-b'),
        where('creatorId', '==', 'cashier-a'),
      )),
    );
    await assertSucceeds(
      getDocs(query(
        collection(viewAllCashier, 'orders'),
        where('merchantId', '==', 'merchant-a'),
        where('branchId', '==', 'branch-a'),
      )),
    );
    await assertSucceeds(
      getDocs(query(
        collection(merchant, 'orders'),
        where('merchantId', '==', 'merchant-a'),
        where('branchId', '==', 'branch-a'),
      )),
    );
    await assertSucceeds(getDoc(doc(cashier, 'products', 'prod-1')));
    await assertFails(getDoc(doc(otherMerchant, 'products', 'prod-1')));
    await assertSucceeds(
      getDoc(
        doc(cashier, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-a_prod-1'),
      ),
    );
    await assertFails(
      getDoc(
        doc(cashier, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-b_prod-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(cashier, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-a_prod-2'),
        {
          id: 'branch-a_prod-2',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          productId: 'prod-2',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertSucceeds(
      getDoc(doc(cashier, 'merchants', 'merchant-a', 'branches', 'branch-a', 'products', 'prod-branch-a')),
    );
    await assertFails(
      getDoc(doc(cashier, 'merchants', 'merchant-a', 'branches', 'branch-b', 'products', 'prod-branch-b')),
    );
    await assertFails(
      setDoc(doc(cashier, 'merchants', 'merchant-a', 'branches', 'branch-b', 'products', 'forged'), {
        id: 'forged',
        merchantId: 'merchant-a',
        branchId: 'branch-b',
        name: 'Forged',
        price: 1,
      }),
    );
    await assertSucceeds(
      getDoc(
        doc(cashier, 'merchants', 'merchant-a', 'raw_material_branch_availability', 'branch-a_raw-1'),
      ),
    );
    await assertFails(
      getDocs(collection(cashier, 'merchants', 'merchant-a', 'product_branch_availability')),
    );
    await assertSucceeds(
      getDocs(query(
        collection(cashier, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility'),
        where('enabled', '==', true),
      )),
    );
    await assertSucceeds(
      getDocs(query(
        collection(cashier, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility'),
        where('enabled', '==', true),
      )),
    );
    await assertFails(
      getDocs(query(
        collection(cashier, 'merchants', 'merchant-a', 'branches', 'branch-b', 'legacy_product_visibility'),
        where('enabled', '==', true),
      )),
    );
    await assertFails(
      getDoc(doc(cashier, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-b_prod-branch-b-only')),
    );
    await assertSucceeds(
      getDoc(doc(cashier, 'merchants', 'merchant-a', 'migration_state', 'legacy_product_visibility_v1_branch-a')),
    );
    await assertSucceeds(
      setDoc(doc(merchant, 'merchants', 'merchant-a', 'migration_state', 'owner_metadata_state'), {
        version: 1,
        status: 'running',
        branchId: 'branch-a',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(merchant, 'merchants', 'merchant-a', 'migration_state', 'owner_metadata_state'), {
        status: 'completed',
      }),
    );
    await assertSucceeds(
      deleteDoc(doc(merchant, 'merchants', 'merchant-a', 'migration_state', 'owner_metadata_state')),
    );
    await assertSucceeds(
      setDoc(
        doc(merchant, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'owner-prod'),
        {
          id: 'owner-prod',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          productId: 'owner-prod',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertSucceeds(
      updateDoc(
        doc(merchant, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'owner-prod'),
        { enabled: false },
      ),
    );
    await assertSucceeds(
      deleteDoc(
        doc(merchant, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'owner-prod'),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(merchant, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'owner-raw'),
        {
          id: 'owner-raw',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          rawMaterialId: 'owner-raw',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertSucceeds(
      updateDoc(
        doc(merchant, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'owner-raw'),
        { enabled: false },
      ),
    );
    await assertSucceeds(
      deleteDoc(
        doc(merchant, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'owner-raw'),
      ),
    );
    await assertSucceeds(
      getDoc(
        doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'prod-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'employee-prod'),
        {
          id: 'employee-prod',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          productId: 'employee-prod',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertFails(
      updateDoc(
        doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'prod-1'),
        { enabled: false },
      ),
    );
    await assertFails(
      deleteDoc(
        doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'prod-1'),
      ),
    );
    await assertFails(
      setDoc(doc(productManager, 'merchants', 'merchant-a', 'migration_state', 'employee_product_state'), {
        version: 1,
        status: 'completed',
        branchId: 'branch-a',
      }),
    );
    await assertFails(
      updateDoc(doc(productManager, 'merchants', 'merchant-a', 'migration_state', 'legacy_product_visibility_v1_branch-a'), {
        status: 'tampered',
      }),
    );
    await assertSucceeds(
      setDoc(doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'products', 'employee-prod'), {
        id: 'employee-prod',
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        name: 'Employee Product',
        price: 12,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'products', 'employee-prod'), {
        price: 13,
      }),
    );
    await assertSucceeds(
      setDoc(doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'categories', 'employee-cat'), {
        id: 'employee-cat',
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        name: 'Employee Category',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(productManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'categories', 'employee-cat'), {
        name: 'Employee Category Updated',
      }),
    );
    await assertSucceeds(
      getDoc(
        doc(inventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'raw-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(inventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'employee-raw'),
        {
          id: 'employee-raw',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          rawMaterialId: 'employee-raw',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertFails(
      updateDoc(
        doc(inventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'raw-1'),
        { enabled: false },
      ),
    );
    await assertFails(
      deleteDoc(
        doc(inventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'raw-1'),
      ),
    );
    await assertFails(
      setDoc(doc(inventoryManager, 'merchants', 'merchant-a', 'migration_state', 'employee_inventory_state'), {
        version: 1,
        status: 'completed',
        branchId: 'branch-a',
      }),
    );
    await assertFails(
      updateDoc(doc(inventoryManager, 'merchants', 'merchant-a', 'migration_state', 'legacy_raw_material_visibility_v1_branch-a'), {
        status: 'tampered',
      }),
    );
    await assertSucceeds(
      setDoc(doc(inventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'raw_materials', 'employee-raw'), {
        id: 'employee-raw',
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        name: 'Employee Raw',
        unit: 'kg',
        quantity: 5,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(inventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'raw_materials', 'employee-raw'), {
        quantity: 7,
      }),
    );
    await assertSucceeds(
      setDoc(doc(inventoryManager, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_raw_employee-raw'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        itemId: 'employee-raw',
        itemType: 'raw_material',
        quantity: 5,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(inventoryManager, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_raw_employee-raw'), {
        quantity: 6,
      }),
    );
    await assertFails(
      setDoc(doc(catalogInventoryManager, 'merchants', 'merchant-a', 'migration_state', 'employee_both_state'), {
        version: 1,
        status: 'completed',
        branchId: 'branch-a',
      }),
    );
    await assertFails(
      setDoc(
        doc(catalogInventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_product_visibility', 'employee-both-prod'),
        {
          id: 'employee-both-prod',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          productId: 'employee-both-prod',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(catalogInventoryManager, 'merchants', 'merchant-a', 'branches', 'branch-a', 'legacy_raw_material_visibility', 'employee-both-raw'),
        {
          id: 'employee-both-raw',
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          rawMaterialId: 'employee-both-raw',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );

    await assertSucceeds(
      getDoc(doc(cashier, 'merchants', 'merchant-a', 'branch_runtime', 'branch-a')),
    );
    await assertSucceeds(
      setDoc(doc(cashier, 'merchants', 'merchant-a', 'branch_runtime', 'branch-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        openShiftId: 'shift-new',
        updatedAt: new Date(),
      }),
    );
    await assertSucceeds(
      setDoc(doc(cashier, 'shifts', 'shift-new'), {
        id: 'shift-new',
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        employeeId: 'cashier-a',
        employeeName: 'Cashier A',
        startTime: new Date(),
        startCash: 100,
        status: 'open',
      }),
    );
    await assertFails(
      setDoc(doc(noShiftCashier, 'shifts', 'shift-no-permission'), {
        id: 'shift-no-permission',
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        employeeId: 'cashier-no-shift',
        employeeName: 'No Shift',
        startTime: new Date(),
        startCash: 100,
        status: 'open',
      }),
    );
    await assertFails(
      setDoc(doc(noShiftCashier, 'merchants', 'merchant-a', 'branch_runtime', 'branch-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        openShiftId: 'shift-no-permission',
        updatedAt: new Date(),
      }),
    );
    await assertFails(
      setDoc(doc(cashier, 'merchants', 'merchant-a', 'branch_runtime', 'branch-b'), {
        merchantId: 'merchant-a',
        branchId: 'branch-b',
        openShiftId: 'shift-wrong-branch',
        updatedAt: new Date(),
      }),
    );

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

    // MTO Checkout Rules Tests
    // Employee with can_create_orders assigned to branch-a:
    // READ branch-local product / raw material: ALLOW
    await assertSucceeds(getDoc(doc(cashier, 'merchants', 'merchant-a', 'branches', 'branch-a', 'products', 'prod-branch-a')));
    await assertSucceeds(getDoc(doc(cashier, 'merchants', 'merchant-a', 'branches', 'branch-a', 'raw_materials', 'raw-1')));

    // GET missing compatibility docs according to narrow get rule: ALLOW
    await assertFails(getDoc(doc(cashier, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-b_prod-1')));
    await assertSucceeds(getDoc(doc(cashier, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-a_prod-1')));

    // DECREMENT same-branch branch_inventory (raw-material quantity) through checkout: ALLOW
    await assertSucceeds(
      updateDoc(
        doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_raw_material_raw-1'),
        { quantity: 8, merchantId: 'merchant-a', branchId: 'branch-a', itemId: 'raw-1', itemType: 'raw_material' },
      ),
    );

    // CREATE checkout inventory_log: ALLOW
    await assertSucceeds(
      setDoc(
        doc(cashier, 'merchants', 'merchant-a', 'inventory_logs', 'log-1'),
        {
          merchantId: 'merchant-a',
          branchId: 'branch-a',
          productId: 'raw-1',
          changeQuantity: -2,
          previousQuantity: 10,
          newQuantity: 8,
          reason: 'Sales invoice #123',
          date: new Date(),
          userEmail: 'cashier-a@example.test',
        },
      ),
    );

    // WRITE raw_material_branch_availability: DENY
    await assertFails(
      setDoc(
        doc(cashier, 'merchants', 'merchant-a', 'raw_material_branch_availability', 'branch-a_raw-1'),
        { enabled: true },
      ),
    );

    // WRITE product_branch_availability: DENY
    await assertFails(
      setDoc(
        doc(cashier, 'merchants', 'merchant-a', 'product_branch_availability', 'branch-a_prod-1'),
        { enabled: true },
      ),
    );

    // Cross-branch targeting: DENY
    await assertFails(
      updateDoc(
        doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'branch-b_raw_material_raw-1'),
        { quantity: 8, merchantId: 'merchant-a', branchId: 'branch-b', itemId: 'raw-1', itemType: 'raw_material' },
      ),
    );

    // Manual Mutation: Arbitrary manual inventory mutation without can_manage_inventory: DENY (tested above with 99 quantity, this is just asserting it works for raw materials as well without required fields)
    await assertFails(
      updateDoc(
        doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_raw_material_raw-1'),
        { quantity: 150 }, // Arbitrary mutation (missing itemType/branchId etc)
      ),
    );

    // Malformed ID: Targeting invalid non-canonical document IDs: DENY
    await assertFails(
      updateDoc(
        doc(cashier, 'merchants', 'merchant-a', 'branch_inventory', 'branch-a_raw_raw-1'), // non canonical, must be raw_material
        { quantity: 8, merchantId: 'merchant-a', branchId: 'branch-a', itemId: 'raw-1', itemType: 'raw_material' },
      ),
    );

    // F11 Stocktake Rules Tests
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'merchants', 'merchant-a', 'stocktakes', 'session-a'), {
        merchantId: 'merchant-a',
        branchId: 'branch-a',
        status: 'counting',
      });
      await setDoc(doc(db, 'merchants', 'merchant-a', 'stocktakes', 'session-b'), {
        merchantId: 'merchant-a',
        branchId: 'branch-b',
        status: 'counting',
      });
      await setDoc(doc(db, 'merchants', 'merchant-a', 'stocktakes', 'session-a', 'lines', 'line-1'), {
        itemType: 'product',
        itemId: 'prod-1',
        difference: 1,
      });
      await setDoc(doc(db, 'merchants', 'merchant-a', 'stocktakes', 'session-b', 'lines', 'line-1'), {
        itemType: 'product',
        itemId: 'prod-1',
        difference: 1,
      });
    });

    // employee assigned Branch A:
    // Stocktake A session read/write ALLOW
    await assertSucceeds(getDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-a')));
    await assertSucceeds(
      updateDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-a'), {
        status: 'completed',
        branchId: 'branch-a',
        merchantId: 'merchant-a'
      })
    );
    // Stocktake A lines read/write ALLOW
    await assertSucceeds(getDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-a', 'lines', 'line-1')));
    await assertSucceeds(
      updateDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-a', 'lines', 'line-1'), {
        difference: 2,
      })
    );

    // same employee:
    // Stocktake B session DENY
    await assertFails(getDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-b')));
    // Stocktake B lines direct GET DENY
    await assertFails(getDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-b', 'lines', 'line-1')));
    // Stocktake B lines direct WRITE DENY
    await assertFails(
      updateDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-b', 'lines', 'line-1'), {
        difference: 2,
      })
    );

    // attempt to mutate Stocktake A branchId to B: DENY
    await assertFails(
      updateDoc(doc(stock, 'merchants', 'merchant-a', 'stocktakes', 'session-a'), {
        branchId: 'branch-b',
        merchantId: 'merchant-a'
      })
    );

  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

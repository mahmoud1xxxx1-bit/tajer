const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc } = require('firebase/firestore');

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
      await setDoc(doc(db, 'users', 'cost-manager-a'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-a'],
        permissions: {
          can_manage_products: true,
          can_view_cost: true,
          can_view_reports: true,
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
      await setDoc(doc(db, 'users', 'auditor-b'), {
        role: 'employee',
        merchantId: 'merchant-a',
        isRevoked: false,
        assignedBranchIds: ['branch-b'],
        permissions: {
          can_view_cost: true,
          can_view_reports: true,
        },
      });
      await setDoc(doc(db, 'merchants', 'merchant-a', 'product_costs', 'legacy-prod'), {
        merchantId: 'merchant-a',
        productId: 'legacy-prod',
        costPrice: 2,
      });
    });

    const merchant = testEnv.authenticatedContext('merchant-a').firestore();
    const managerA = testEnv.authenticatedContext('cost-manager-a').firestore();
    const auditorA = testEnv.authenticatedContext('auditor-a').firestore();
    const auditorB = testEnv.authenticatedContext('auditor-b').firestore();

    const branchACost = doc(
      managerA,
      'merchants', 'merchant-a', 'product_costs', 'branch-a_prod-1',
    );
    await assertSucceeds(setDoc(branchACost, {
      merchantId: 'merchant-a',
      branchId: 'branch-a',
      productId: 'prod-1',
      costPrice: 4.5,
      updatedAt: new Date(),
    }));

    await assertSucceeds(getDoc(doc(
      auditorA,
      'merchants', 'merchant-a', 'product_costs', 'branch-a_prod-1',
    )));
    await assertFails(getDoc(doc(
      auditorB,
      'merchants', 'merchant-a', 'product_costs', 'branch-a_prod-1',
    )));

    await assertFails(setDoc(doc(
      managerA,
      'merchants', 'merchant-a', 'product_costs', 'branch-b_prod-2',
    ), {
      merchantId: 'merchant-a',
      branchId: 'branch-b',
      productId: 'prod-2',
      costPrice: 8,
      updatedAt: new Date(),
    }));

    await assertSucceeds(getDoc(doc(
      auditorA,
      'merchants', 'merchant-a', 'product_costs', 'legacy-prod',
    )));
    await assertFails(setDoc(doc(
      managerA,
      'merchants', 'merchant-a', 'product_costs', 'employee-legacy',
    ), {
      merchantId: 'merchant-a',
      productId: 'employee-legacy',
      costPrice: 3,
      updatedAt: new Date(),
    }));
    await assertSucceeds(setDoc(doc(
      merchant,
      'merchants', 'merchant-a', 'product_costs', 'owner-legacy',
    ), {
      merchantId: 'merchant-a',
      productId: 'owner-legacy',
      costPrice: 3,
      updatedAt: new Date(),
      migratedFromLegacyProduct: true,
    }));

    console.log('PASS: branch-aware and legacy protected product cost rules');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

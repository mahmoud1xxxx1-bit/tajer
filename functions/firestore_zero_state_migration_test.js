const assert = require('assert');
const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  documentId,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

const projectId = 'demo-tajer-zero-state';
const merchantId = 'zero-state-owner';
const branchId = 'branch-a';

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });

  try {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users', merchantId), {
        role: 'merchant',
        isRevoked: false,
      });
      await setDoc(doc(db, 'users', 'employee-a'), {
        role: 'employee',
        merchantId,
        isRevoked: false,
        assignedBranchIds: [branchId],
        permissions: {
          can_manage_products: true,
          can_manage_inventory: true,
        },
      });
      for (const id of ['main', branchId, 'branch-b']) {
        await setDoc(doc(db, 'merchants', merchantId, 'branches', id), {
          id,
          merchantId,
          name: id,
          isMain: id === 'main',
          isActive: true,
        });
      }
      await setDoc(doc(db, 'products', 'legacy-product'), {
        id: 'legacy-product',
        merchantId,
        name: 'Legacy product',
        price: 10,
        quantity: 0,
        isArchived: false,
      });
      await setDoc(doc(db, 'raw_materials', 'legacy-raw'), {
        id: 'legacy-raw',
        merchantId,
        name: 'Legacy raw',
        quantity: 0,
        initialQuantity: 0,
        unit: 'piece',
        isArchived: false,
      });
      await setDoc(
        doc(db, 'merchants', merchantId, 'categories', 'legacy-category'),
        {
          id: 'legacy-category',
          merchantId,
          name: 'Legacy category',
        },
      );
      await setDoc(
        doc(
          db,
          'merchants',
          merchantId,
          'product_branch_availability',
          `${branchId}_legacy-product`,
        ),
        {
          id: `${branchId}_legacy-product`,
          merchantId,
          branchId,
          productId: 'legacy-product',
          enabled: true,
          updatedAt: new Date(),
        },
      );
      await setDoc(
        doc(
          db,
          'merchants',
          merchantId,
          'raw_material_branch_availability',
          `${branchId}_legacy-raw`,
        ),
        {
          id: `${branchId}_legacy-raw`,
          merchantId,
          branchId,
          rawMaterialId: 'legacy-raw',
          enabled: true,
          updatedAt: new Date(),
        },
      );
    });

    const owner = testEnv
      .authenticatedContext(merchantId, { email: 'owner@example.test' })
      .firestore();
    const employee = testEnv
      .authenticatedContext('employee-a', { email: 'employee@example.test' })
      .firestore();
    const stateCollection = collection(
      owner,
      'merchants',
      merchantId,
      'migration_state',
    );
    const visibilityState = doc(
      stateCollection,
      `legacy_product_visibility_v1_${branchId}`,
    );

    const missingState = await assertSucceeds(getDoc(visibilityState));
    assert.strictEqual(missingState.exists(), false);

    await assertSucceeds(
      setDoc(visibilityState, {
        version: 1,
        status: 'running',
        branchId,
      }),
    );
    await assertSucceeds(updateDoc(visibilityState, { status: 'completed' }));

    const legacyProducts = await assertSucceeds(
      getDocs(
        query(
          collection(owner, 'products'),
          where('merchantId', '==', merchantId),
          orderBy(documentId()),
        ),
      ),
    );
    assert.strictEqual(legacyProducts.size, 1);
    await assertSucceeds(
      getDocs(
        query(
          collection(owner, 'merchants', merchantId, 'branch_inventory'),
          where('branchId', '==', branchId),
          where('itemType', '==', 'product'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        collection(
          owner,
          'merchants',
          merchantId,
          'product_branch_availability',
        ),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(
          owner,
          'merchants',
          merchantId,
          'branches',
          branchId,
          'legacy_product_visibility',
          'legacy-product',
        ),
        {
          id: 'legacy-product',
          merchantId,
          branchId,
          productId: 'legacy-product',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(
          owner,
          'merchants',
          merchantId,
          'branches',
          branchId,
          'products',
          'legacy-product',
        ),
        {
          id: 'legacy-product',
          merchantId,
          branchId,
          name: 'Legacy product',
          price: 10,
          quantity: 0,
          isArchived: false,
        },
      ),
    );

    const legacyRawMaterials = await assertSucceeds(
      getDocs(
        query(
          collection(owner, 'raw_materials'),
          where('merchantId', '==', merchantId),
          orderBy(documentId()),
        ),
      ),
    );
    assert.strictEqual(legacyRawMaterials.size, 1);
    await assertSucceeds(
      getDocs(
        collection(
          owner,
          'merchants',
          merchantId,
          'raw_material_branch_availability',
        ),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(
          owner,
          'merchants',
          merchantId,
          'branches',
          branchId,
          'legacy_raw_material_visibility',
          'legacy-raw',
        ),
        {
          id: 'legacy-raw',
          merchantId,
          branchId,
          rawMaterialId: 'legacy-raw',
          enabled: true,
          updatedAt: new Date(),
        },
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(
          owner,
          'merchants',
          merchantId,
          'branches',
          branchId,
          'raw_materials',
          'legacy-raw',
        ),
        {
          id: 'legacy-raw',
          merchantId,
          branchId,
          name: 'Legacy raw',
          quantity: 0,
          initialQuantity: 0,
          unit: 'piece',
          isArchived: false,
        },
      ),
    );

    const legacyCategories = await assertSucceeds(
      getDocs(
        query(
          collection(owner, 'merchants', merchantId, 'categories'),
          orderBy(documentId()),
        ),
      ),
    );
    assert.strictEqual(legacyCategories.size, 1);
    await assertSucceeds(
      setDoc(
        doc(
          owner,
          'merchants',
          merchantId,
          'branches',
          branchId,
          'categories',
          'legacy-category',
        ),
        {
          id: 'legacy-category',
          merchantId,
          branchId,
          name: 'Legacy category',
        },
      ),
    );

    for (const stateId of [
      `legacy_raw_material_visibility_v1_${branchId}`,
      `branch_catalog_v1_${branchId}`,
      `branch_raw_materials_v1_${branchId}`,
      `branch_categories_v1_${branchId}`,
    ]) {
      const stateRef = doc(stateCollection, stateId);
      const firstRead = await assertSucceeds(getDoc(stateRef));
      assert.strictEqual(firstRead.exists(), false);
      await assertSucceeds(
        setDoc(stateRef, {
          version: 1,
          status: 'completed',
          branchId,
        }),
      );
    }

    await assertSucceeds(
      getDoc(
        doc(
          employee,
          'merchants',
          merchantId,
          'migration_state',
          `legacy_product_visibility_v1_${branchId}`,
        ),
      ),
    );
    await assertFails(
      getDoc(
        doc(
          employee,
          'merchants',
          merchantId,
          'migration_state',
          'missing-assigned-branch-state',
        ),
      ),
    );
    await assertFails(
      getDoc(
        doc(
          employee,
          'merchants',
          merchantId,
          'migration_state',
          'missing-other-branch-state',
        ),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          employee,
          'merchants',
          merchantId,
          'migration_state',
          'employee-write',
        ),
        { version: 1, status: 'completed', branchId },
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(
            employee,
            'merchants',
            merchantId,
            'migration_state',
          ),
          where('branchId', '==', branchId),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collection(
            employee,
            'merchants',
            merchantId,
            'migration_state',
          ),
          where('branchId', '==', 'branch-b'),
        ),
      ),
    );
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

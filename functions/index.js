const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();

const captureOrderCostSnapshotHandler = async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const order = snapshot.data();
  const merchantId = String(order.merchantId || '').trim();
  const orderId = event.params.orderId;
  const branchId = String(order.branchId || 'main').trim();
  if (!merchantId || !orderId) return;

  const db = getFirestore();
  const targetRef = db
    .collection('merchants')
    .doc(merchantId)
    .collection('order_cost_snapshots')
    .doc(orderId);

  const existing = await targetRef.get();
  if (existing.exists) return;

  const rawItems = Array.isArray(order.items) ? order.items : [];
  if (rawItems.length === 0) return;

  const productIds = [...new Set(
    rawItems
      .map((item) => String(item?.productId || '').trim())
      .filter(Boolean),
  )];

  // Fetch Products (Branch-aware with legacy fallback)
  const productDocs = new Map();
  if (productIds.length > 0) {
    const branchProductRefs = productIds.map(id =>
      db.collection('merchants').doc(merchantId).collection('branches').doc(branchId).collection('products').doc(id)
    );
    const branchProducts = await db.getAll(...branchProductRefs);
    
    const missingProductIds = [];
    branchProducts.forEach((doc, i) => {
      if (doc.exists) {
        productDocs.set(productIds[i], doc.data());
      } else {
        missingProductIds.push(productIds[i]);
      }
    });

    if (missingProductIds.length > 0) {
      const legacyProductRefs = missingProductIds.map(id =>
        db.collection('merchants').doc(merchantId).collection('products').doc(id)
      );
      const legacyProducts = await db.getAll(...legacyProductRefs);
      legacyProducts.forEach((doc, i) => {
        if (doc.exists) {
          productDocs.set(missingProductIds[i], doc.data());
        }
      });
    }
  }

  // Identify MTO and collect raw material IDs
  const rawMaterialIds = new Set();
  const itemMeta = rawItems.map(item => {
    const productId = String(item?.productId || '').trim();
    const product = productDocs.get(productId);
    const isMTO = item?.isManufacturedOnDemand || (product?.isManufacturedOnDemand === true);
    let recipe = [];
    if (isMTO && product && Array.isArray(product.recipe)) {
      recipe = product.recipe;
      recipe.forEach(raw => {
        const rawId = String(raw?.rawMaterialId || '').trim();
        if (rawId) rawMaterialIds.add(rawId);
      });
    }
    return { productId, isMTO, recipe };
  });

  const costIds = [...new Set([...productIds, ...Array.from(rawMaterialIds)])];

  // Fetch Costs (Branch-aware with legacy fallback)
  const costs = new Map();
  if (costIds.length > 0) {
    const branchCostRefs = costIds.map(id =>
      db.collection('merchants').doc(merchantId).collection('product_costs').doc(`${branchId}_${id}`)
    );
    const branchCosts = await db.getAll(...branchCostRefs);
    
    const missingCostIds = [];
    branchCosts.forEach((doc, i) => {
      const val = doc.data()?.costPrice;
      if (typeof val === 'number' && Number.isFinite(val) && val >= 0) {
        costs.set(costIds[i], val);
      } else {
        missingCostIds.push(costIds[i]);
      }
    });

    if (missingCostIds.length > 0) {
      const legacyCostRefs = missingCostIds.map(id =>
        db.collection('merchants').doc(merchantId).collection('product_costs').doc(id)
      );
      const legacyCosts = await db.getAll(...legacyCostRefs);
      legacyCosts.forEach((doc, i) => {
        const val = doc.data()?.costPrice;
        if (typeof val === 'number' && Number.isFinite(val) && val >= 0) {
          costs.set(missingCostIds[i], val);
        }
      });
    }
  }

  // Calculate COGS
  let calculatedTotalCost = 0;
  let complete = true;
  
  const protectedItems = rawItems.map((item, index) => {
    const meta = itemMeta[index];
    const quantity = Number.isFinite(Number(item?.quantity))
      ? Math.max(0, Number(item.quantity))
      : 0;

    const productId = meta.productId;
    let unitCost;
    
    if (meta.isMTO) {
      let recipeComplete = true;
      let recipeUnitCost = 0;
      if (meta.recipe.length === 0) recipeComplete = false;
      
      for (const raw of meta.recipe) {
        const rawId = String(raw?.rawMaterialId || '').trim();
        const amount = Number(raw?.amountRequired);
        const rawCost = costs.get(rawId);
        
        if (!rawId || !Number.isFinite(amount) || amount <= 0 || rawCost === undefined) {
          recipeComplete = false;
          break;
        }
        recipeUnitCost += (rawCost * amount);
      }
      unitCost = recipeComplete ? recipeUnitCost : undefined;
    } else {
      unitCost = costs.get(productId);
    }

    if (unitCost === undefined) complete = false;
    
    const lineCost = unitCost === undefined ? null : unitCost * quantity;
    if (lineCost !== null) calculatedTotalCost += lineCost;

    return {
      productId: meta.productId,
      productName: String(item?.productName || ''),
      quantity,
      unitCost: unitCost ?? null,
      lineCost,
    };
  });

  try {
    await targetRef.create({
      merchantId,
      orderId,
      branchId,
      items: protectedItems,
      totalCost: complete ? calculatedTotalCost : null,
      isComplete: complete,
      source: 'trusted_server_trigger',
      orderCreatedAt: order.createdAt || null,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (error && (error.code === 6 || error.code === 'already-exists')) {
      return;
    }
    throw error;
  }
};

exports.captureOrderCostSnapshot = onDocumentCreated(
  {
    document: 'orders/{orderId}',
    region: 'europe-west1',
    retry: true,
  },
  captureOrderCostSnapshotHandler
);

exports._testCaptureOrderCostSnapshotHandler = captureOrderCostSnapshotHandler;

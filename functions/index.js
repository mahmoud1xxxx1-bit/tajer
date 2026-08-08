const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();

exports.captureOrderCostSnapshot = onDocumentCreated(
  {
    document: 'orders/{orderId}',
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const order = snapshot.data();
    const merchantId = String(order.merchantId || '').trim();
    const orderId = event.params.orderId;
    if (!merchantId || !orderId) return;

    const db = getFirestore();
    const targetRef = db
      .collection('merchants')
      .doc(merchantId)
      .collection('order_cost_snapshots')
      .doc(orderId);

    // Idempotency: Firestore triggers are at-least-once. Never overwrite a
    // historical snapshot that has already been captured for this order.
    const existing = await targetRef.get();
    if (existing.exists) return;

    const rawItems = Array.isArray(order.items) ? order.items : [];
    const productIds = [...new Set(
      rawItems
        .map((item) => String(item?.productId || '').trim())
        .filter(Boolean),
    )];

    const costRefs = productIds.map((productId) =>
      db.collection('merchants').doc(merchantId).collection('product_costs').doc(productId),
    );
    const costDocs = costRefs.length > 0 ? await db.getAll(...costRefs) : [];
    const costs = new Map();
    for (const costDoc of costDocs) {
      const value = costDoc.data()?.costPrice;
      if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
        costs.set(costDoc.id, value);
      }
    }

    let totalCost = 0;
    let complete = true;
    const protectedItems = rawItems.map((item) => {
      const productId = String(item?.productId || '').trim();
      const quantity = Number.isFinite(Number(item?.quantity))
        ? Math.max(0, Number(item.quantity))
        : 0;
      const unitCost = costs.get(productId);
      if (unitCost === undefined) complete = false;
      const safeUnitCost = unitCost ?? 0;
      const lineCost = safeUnitCost * quantity;
      totalCost += lineCost;
      return {
        productId,
        productName: String(item?.productName || ''),
        quantity,
        unitCost: unitCost ?? null,
        lineCost: unitCost === undefined ? null : lineCost,
      };
    });

    await targetRef.create({
      merchantId,
      orderId,
      branchId: String(order.branchId || 'main'),
      items: protectedItems,
      totalCost,
      isComplete: complete,
      source: 'trusted_server_trigger',
      orderCreatedAt: order.createdAt || null,
      createdAt: FieldValue.serverTimestamp(),
    });
  },
);

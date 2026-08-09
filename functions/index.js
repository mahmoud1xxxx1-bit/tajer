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

    // Firestore triggers are at-least-once. The historical cost of an order is
    // immutable, so an already-captured snapshot must never be overwritten by a
    // retry or by a later product cost change.
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

    let calculatedTotalCost = 0;
    let complete = true;
    const protectedItems = rawItems.map((item) => {
      const productId = String(item?.productId || '').trim();
      const quantity = Number.isFinite(Number(item?.quantity))
        ? Math.max(0, Number(item.quantity))
        : 0;
      const unitCost = costs.get(productId);
      if (unitCost === undefined) complete = false;
      const lineCost = unitCost === undefined ? null : unitCost * quantity;
      if (lineCost !== null) calculatedTotalCost += lineCost;
      return {
        productId,
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
        branchId: String(order.branchId || 'main'),
        items: protectedItems,
        // A partial total must never masquerade as valid profit data. Readers only
        // consume numeric totalCost values, so null makes COGS completeness fail
        // closed until all sold items have an authoritative cost snapshot.
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
  },
);

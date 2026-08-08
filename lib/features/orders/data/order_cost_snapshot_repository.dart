import 'package:cloud_firestore/cloud_firestore.dart';

/// Sensitive historical COGS is stored separately from public order documents.
/// This lets Firestore Rules enforce can_view_cost without hiding normal sales
/// history from employees who are otherwise allowed to read an order.
class OrderCostSnapshotRepository {
  final FirebaseFirestore _firestore;

  OrderCostSnapshotRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _ref(String merchantId) =>
      _firestore.collection('merchants').doc(merchantId).collection('order_cost_snapshots');

  Stream<Map<String, double>> watchOrderCosts(String merchantId) {
    return _ref(merchantId).snapshots().map((snapshot) => {
          for (final doc in snapshot.docs)
            doc.id: (doc.data()['totalCost'] as num?)?.toDouble() ?? 0.0,
        });
  }

  Stream<Map<String, double>> watchBranchOrderCosts(
    String merchantId,
    String branchId,
  ) {
    return _ref(merchantId)
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map((snapshot) => {
              for (final doc in snapshot.docs)
                doc.id: (doc.data()['totalCost'] as num?)?.toDouble() ?? 0.0,
            });
  }

  /// One-way v107 compatibility migration. It preserves the per-item historical
  /// cost snapshot in the protected collection, then strips costPrice from the
  /// public order items in the same batch. Run only as merchant/admin.
  Future<void> migrateLegacyOrderCosts(String merchantId) async {
    final orders = await _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .get();

    final legacy = orders.docs.where((doc) {
      final items = doc.data()['items'];
      return items is List && items.any((item) => item is Map && item['costPrice'] != null);
    }).toList();
    if (legacy.isEmpty) return;

    // Two writes per order; keep comfortably below Firestore batch limits.
    const ordersPerBatch = 200;
    for (var start = 0; start < legacy.length; start += ordersPerBatch) {
      final end = (start + ordersPerBatch < legacy.length)
          ? start + ordersPerBatch
          : legacy.length;
      final batch = _firestore.batch();

      for (final orderDoc in legacy.sublist(start, end)) {
        final data = orderDoc.data();
        final rawItems = (data['items'] as List<dynamic>? ?? const []);
        final protectedItems = <Map<String, dynamic>>[];
        final publicItems = <Map<String, dynamic>>[];
        double totalCost = 0.0;

        for (final raw in rawItems) {
          final item = Map<String, dynamic>.from(raw as Map);
          final rawCost = item['costPrice'];
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          if (rawCost is num) {
            final unitCost = rawCost.toDouble();
            protectedItems.add({
              'productId': item['productId']?.toString() ?? '',
              'productName': item['productName']?.toString() ?? '',
              'quantity': quantity,
              'unitCost': unitCost,
              'lineCost': unitCost * quantity,
            });
            totalCost += unitCost * quantity;
          }
          item.remove('costPrice');
          publicItems.add(item);
        }

        batch.set(_ref(merchantId).doc(orderDoc.id), {
          'merchantId': merchantId,
          'orderId': orderDoc.id,
          'branchId': data['branchId']?.toString() ?? 'main',
          'items': protectedItems,
          'totalCost': totalCost,
          'createdAt': data['createdAt'],
          'migratedFromLegacyOrder': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.update(orderDoc.reference, {'items': publicItems});
      }

      await batch.commit();
    }
  }
}

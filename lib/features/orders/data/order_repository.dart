import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/order.dart';

part 'order_repository.g.dart';

class OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepository(this._firestore);

  Query<AppOrder> queryOrders(String merchantId) {
    return _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .withConverter(
          fromFirestore: (snapshot, _) => AppOrder.fromJson(snapshot.data()!),
          toFirestore: (order, _) => order.toJson(),
        );
  }

  Future<void> createOrder(AppOrder order) async {
    // We use a transaction to ensure inventory is reduced safely
    // and customer stats are updated concurrently.
    await _firestore.runTransaction((transaction) async {
      final productRef = _firestore.collection('products').doc(order.productId);
      final customerRef = _firestore.collection('customers').doc(order.customerId);
      final orderRef = _firestore.collection('orders').doc(order.id);

      final productDoc = await transaction.get(productRef);
      if (!productDoc.exists) throw Exception('المنتج غير موجود');

      final currentQuantity = productDoc.data()?['quantity'] as int? ?? 0;
      if (currentQuantity < order.quantity) {
        throw Exception('الكمية غير كافية في المخزون');
      }

      final customerDoc = await transaction.get(customerRef);
      if (!customerDoc.exists) throw Exception('العميل غير موجود');

      final currentTotalPurchases = (customerDoc.data()?['totalPurchases'] as num?)?.toDouble() ?? 0.0;
      final currentOrderCount = customerDoc.data()?['orderCount'] as int? ?? 0;

      // Update product inventory
      transaction.update(productRef, {
        'quantity': currentQuantity - order.quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update customer stats
      transaction.update(customerRef, {
        'totalPurchases': currentTotalPurchases + order.total,
        'orderCount': currentOrderCount + 1,
        'lastPurchaseDate': FieldValue.serverTimestamp(),
      });

      // Save order
      transaction.set(orderRef, order.toJson());
    });
  }

  Future<void> deleteOrder(AppOrder order) async {
    await _firestore.runTransaction((transaction) async {
      final productRef = _firestore.collection('products').doc(order.productId);
      final customerRef = _firestore.collection('customers').doc(order.customerId);
      final orderRef = _firestore.collection('orders').doc(order.id);

      final orderDoc = await transaction.get(orderRef);
      if (!orderDoc.exists) return; // Already deleted

      final productDoc = await transaction.get(productRef);
      if (productDoc.exists) {
        final currentQuantity = productDoc.data()?['quantity'] as int? ?? 0;
        // Restore inventory
        transaction.update(productRef, {
          'quantity': currentQuantity + order.quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final customerDoc = await transaction.get(customerRef);
      if (customerDoc.exists) {
        final currentTotalPurchases = (customerDoc.data()?['totalPurchases'] as num?)?.toDouble() ?? 0.0;
        final currentOrderCount = customerDoc.data()?['orderCount'] as int? ?? 0;
        // Revert customer stats
        transaction.update(customerRef, {
          'totalPurchases': (currentTotalPurchases - order.total).clamp(0.0, double.infinity),
          'orderCount': (currentOrderCount - 1).clamp(0, int.MAX_VALUE),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Delete order
      transaction.delete(orderRef);
    });
  }

  Future<int> getOrderCount(String merchantId) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

@riverpod
OrderRepository orderRepository(OrderRepositoryRef ref) {
  return OrderRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<List<AppOrder>> ordersStream(OrdersStreamRef ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return const Stream.empty();

  final repository = ref.watch(orderRepositoryProvider);
  return repository.queryOrders(user.uid).snapshots().map(
        (snapshot) {
          final orders = snapshot.docs.map((doc) => doc.data()).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        },
      );
}

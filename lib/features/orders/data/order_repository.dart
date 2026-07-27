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
          fromFirestore: (snapshot, _) {
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            data['merchantId'] = data['merchantId']?.toString() ?? '';
            data['quantity'] = (data['quantity'] ?? 0).toInt();
            data['total'] = (data['total'] ?? 0.0).toDouble();
            data['productId'] = data['productId']?.toString() ?? '';
            data['productName'] = data['productName']?.toString() ?? '';
            data['customerId'] = data['customerId']?.toString() ?? '';
            data['customerName'] = data['customerName']?.toString() ?? '';
            data['status'] = data['status']?.toString() ?? 'pending';
            data['paidAmount'] = (data['paidAmount'] ?? 0.0).toDouble();
            data['isCredit'] = data['isCredit'] ?? false;
            return AppOrder.fromJson(data);
          },
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
      final currentTotalDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;

      // Update product inventory
      transaction.update(productRef, {
        'quantity': currentQuantity - order.quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update customer stats
      final debtIncrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
      transaction.update(customerRef, {
        'totalPurchases': currentTotalPurchases + order.total,
        'orderCount': currentOrderCount + 1,
        'totalDebt': currentTotalDebt + debtIncrease,
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
        final currentTotalDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
        
        // Revert customer stats
        final newOrderCount = currentOrderCount - 1;
        final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
        
        transaction.update(customerRef, {
          'totalPurchases': (currentTotalPurchases - order.total).clamp(0.0, double.infinity),
          'orderCount': newOrderCount < 0 ? 0 : newOrderCount,
          'totalDebt': (currentTotalDebt - debtDecrease).clamp(0.0, double.infinity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Delete order
      transaction.delete(orderRef);
    });
  }

  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.status == newStatus) return;

    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(order.id);
      final productRef = _firestore.collection('products').doc(order.productId);

      if (newStatus == 'cancelled' && order.status != 'cancelled') {
        // Restoring inventory
        final productDoc = await transaction.get(productRef);
        if (productDoc.exists) {
          final currentQty = productDoc.data()?['quantity'] as int? ?? 0;
          transaction.update(productRef, {
            'quantity': currentQty + order.quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
        // Reducing inventory again
        final productDoc = await transaction.get(productRef);
        if (productDoc.exists) {
          final currentQty = productDoc.data()?['quantity'] as int? ?? 0;
          if (currentQty < order.quantity) {
            throw Exception('الكمية غير كافية لإعادة تفعيل الطلب');
          }
          transaction.update(productRef, {
            'quantity': currentQty - order.quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          throw Exception('المنتج غير موجود');
        }
      }

      transaction.update(orderRef, {'status': newStatus});
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

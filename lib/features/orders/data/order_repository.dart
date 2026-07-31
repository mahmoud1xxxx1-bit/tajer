import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/l10n/app_localizations.dart';
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
            data['customerId'] = data['customerId']?.toString() ?? '';
            data['customerName'] = data['customerName']?.toString() ?? '';
            data['status'] = data['status']?.toString() ?? 'pending';
            data['paidAmount'] = (data['paidAmount'] ?? 0.0).toDouble();
            data['isCredit'] = data['isCredit'] ?? false;
            
            // Backward compatibility: Convert old single product order to items list
            if (data['items'] == null && data['productId'] != null) {
              data['items'] = [
                {
                  'productId': data['productId']?.toString() ?? '',
                  'productName': data['productName']?.toString() ?? '',
                  'quantity': (data['quantity'] ?? 0).toInt(),
                  'price': (data['price'] ?? 0.0).toDouble(),
                  'total': data['total'],
                }
              ];
            } else if (data['items'] != null) {
              data['items'] = List<Map<String, dynamic>>.from(data['items'].map((x) => Map<String, dynamic>.from(x)));
            } else {
              data['items'] = [];
            }
            
            return AppOrder.fromJson(data);
          },
          toFirestore: (order, _) => order.toJson(),
        );
  }

  Future<void> createOrder(AppOrder order) async {
    await _firestore.runTransaction((transaction) async {
      final customerRef = _firestore.collection('customers').doc(order.customerId);
      final orderRef = _firestore.collection('orders').doc(order.id);

      // Verify all products and update inventory
      for (final item in order.items) {
        final productRef = _firestore.collection('products').doc(item.productId);
        final productDoc = await transaction.get(productRef);
        if (!productDoc.exists) throw Exception("المنتج غير موجود: ${item.productName}");

        final currentQuantity = productDoc.data()?['quantity'] as int? ?? 0;
        if (currentQuantity < item.quantity) {
          throw Exception("الكمية المطلوبة غير متوفرة للمنتج: ${item.productName}");
        }

        transaction.update(productRef, {
          'quantity': currentQuantity - item.quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (order.customerId != 'walk_in') {
        final customerDoc = await transaction.get(customerRef);
        if (!customerDoc.exists) throw Exception("العميل غير موجود");

        final currentTotalPurchases = (customerDoc.data()?['totalPurchases'] as num?)?.toDouble() ?? 0.0;
        final currentOrderCount = customerDoc.data()?['orderCount'] as int? ?? 0;
        final currentTotalDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;

        final debtIncrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
        transaction.update(customerRef, {
          'totalPurchases': currentTotalPurchases + order.total,
          'orderCount': currentOrderCount + 1,
          'totalDebt': currentTotalDebt + debtIncrease,
          'lastPurchaseDate': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(orderRef, order.toJson());
    });
  }

  Future<void> deleteOrder(AppOrder order) async {
    await _firestore.runTransaction((transaction) async {
      final customerRef = _firestore.collection('customers').doc(order.customerId);
      final orderRef = _firestore.collection('orders').doc(order.id);

      final orderDoc = await transaction.get(orderRef);
      if (!orderDoc.exists) return; // Already deleted

      for (final item in order.items) {
        final productRef = _firestore.collection('products').doc(item.productId);
        final productDoc = await transaction.get(productRef);
        if (productDoc.exists) {
          final currentQuantity = productDoc.data()?['quantity'] as int? ?? 0;
          transaction.update(productRef, {
            'quantity': currentQuantity + item.quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (order.customerId != 'walk_in') {
        final customerDoc = await transaction.get(customerRef);
        if (customerDoc.exists) {
          final currentTotalPurchases = (customerDoc.data()?['totalPurchases'] as num?)?.toDouble() ?? 0.0;
          final currentOrderCount = customerDoc.data()?['orderCount'] as int? ?? 0;
          final currentTotalDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
          
          final newOrderCount = currentOrderCount - 1;
          final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
          
          transaction.update(customerRef, {
            'totalPurchases': (currentTotalPurchases - order.total).clamp(0.0, double.infinity),
            'orderCount': newOrderCount < 0 ? 0 : newOrderCount,
            'totalDebt': (currentTotalDebt - debtDecrease).clamp(0.0, double.infinity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.delete(orderRef);
    });
  }

  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.status == newStatus) return;

    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(order.id);

      for (final item in order.items) {
        final productRef = _firestore.collection('products').doc(item.productId);
        final productDoc = await transaction.get(productRef);

        if (newStatus == 'cancelled' && order.status != 'cancelled') {
          if (productDoc.exists) {
            final currentQty = productDoc.data()?['quantity'] as int? ?? 0;
            transaction.update(productRef, {
              'quantity': currentQty + item.quantity,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
          if (productDoc.exists) {
            final currentQty = productDoc.data()?['quantity'] as int? ?? 0;
            if (currentQty < item.quantity) {
              throw Exception("لا يوجد كمية كافية للإرجاع للمنتج: ${item.productName}");
            }
            transaction.update(productRef, {
              'quantity': currentQty - item.quantity,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            throw Exception("المنتج غير موجود: ${item.productName}");
          }
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
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final repository = ref.watch(orderRepositoryProvider);
  return repository.queryOrders(appUser.merchantId ?? appUser.id).snapshots().map(
        (snapshot) {
          var orders = snapshot.docs.map((doc) => doc.data()).toList();
          
          if (!appUser.hasPermission('can_view_all_orders')) {
            final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
            orders = orders.where((o) => o.createdAt.isAfter(sevenDaysAgo)).toList();
          }
          
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        },
      );
}


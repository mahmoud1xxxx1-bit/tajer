import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<AppOrder> createOrder(AppOrder order, {String? shiftId}) async {
    final batch = _firestore.batch();
    
    final customerRef = _firestore.collection('customers').doc(order.customerId);
    final orderRef = _firestore.collection('orders').doc(order.id);
    
    // Manage QueueNumber Atomically via Firestore Transaction (with local fallback)
    int nextQueueNumber = 1;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();

    try {
      final counterRef = _firestore.collection('merchants').doc(order.merchantId).collection('counters').doc('daily_orders');
      nextQueueNumber = await _firestore.runTransaction<int>((transaction) async {
        final docSnap = await transaction.get(counterRef);
        if (docSnap.exists) {
          final data = docSnap.data()!;
          final lastDate = data['date'] as String?;
          if (lastDate == todayStr) {
            final lastNum = (data['lastNumber'] as num? ?? 0).toInt();
            final nextNum = lastNum + 1;
            transaction.update(counterRef, {'lastNumber': nextNum, 'date': todayStr, 'updatedAt': FieldValue.serverTimestamp()});
            return nextNum;
          } else {
            // New day! Reset counter to 1
            transaction.update(counterRef, {'date': todayStr, 'lastNumber': 1, 'updatedAt': FieldValue.serverTimestamp()});
            return 1;
          }
        } else {
          transaction.set(counterRef, {'date': todayStr, 'lastNumber': 1, 'updatedAt': FieldValue.serverTimestamp()});
          return 1;
        }
      }).timeout(const Duration(seconds: 4));
      
      // Update local prefs to stay in sync with server counter
      await prefs.setString('queue_date_${order.merchantId}', todayStr);
      await prefs.setInt('queue_num_${order.merchantId}', nextQueueNumber);
    } catch (e) {
      // Offline fallback: use SharedPreferences sequentially
      final lastDate = prefs.getString('queue_date_${order.merchantId}');
      if (lastDate == todayStr) {
        nextQueueNumber = (prefs.getInt('queue_num_${order.merchantId}') ?? 0) + 1;
      } else {
        nextQueueNumber = 1;
      }
      await prefs.setString('queue_date_${order.merchantId}', todayStr);
      await prefs.setInt('queue_num_${order.merchantId}', nextQueueNumber);
    }
    
    final orderWithQueue = order.copyWith(queueNumber: nextQueueNumber);

    for (final item in order.items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      
      // Fetch product to get its recipe
      final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));
      if (productDoc.exists) {
        final data = productDoc.data()!;
        final recipeList = data['recipe'] as List<dynamic>? ?? [];
        
        if (recipeList.isNotEmpty) {
          // Has recipe -> deduct raw materials
          for (final recipeItem in recipeList) {
            final rawMaterialId = recipeItem['rawMaterialId'] as String;
            final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
            
            final rawMaterialRef = _firestore.collection('raw_materials').doc(rawMaterialId);
            batch.update(rawMaterialRef, {
              'quantity': FieldValue.increment(-(amountRequired * item.quantity)),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // No recipe -> deduct product quantity
          batch.update(productRef, {
            'quantity': FieldValue.increment(-item.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    if (order.customerId != 'walk_in') {
      final debtIncrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
      batch.update(customerRef, {
        'totalPurchases': FieldValue.increment(order.total),
        'orderCount': FieldValue.increment(1),
        'totalDebt': FieldValue.increment(debtIncrease),
        'lastPurchaseDate': FieldValue.serverTimestamp(),
      });
    }

    if (shiftId != null) {
      final shiftRef = _firestore.collection('shifts').doc(shiftId);
      if (order.paymentMethod == 'cash') {
        batch.update(shiftRef, {'cashSales': FieldValue.increment(order.paidAmount)});
      } else if (order.paymentMethod == 'card') {
        batch.update(shiftRef, {'cardTotal': FieldValue.increment(order.paidAmount)});
      } else if (order.paymentMethod == 'transfer') {
        batch.update(shiftRef, {'transferTotal': FieldValue.increment(order.paidAmount)});
      }
    }

    batch.set(orderRef, orderWithQueue.toJson());
    await batch.commit();
    return orderWithQueue;
  }

  Future<void> deleteOrder(AppOrder order) async {
    final batch = _firestore.batch();
    final customerRef = _firestore.collection('customers').doc(order.customerId);
    final orderRef = _firestore.collection('orders').doc(order.id);

    for (final item in order.items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));
      if (productDoc.exists) {
        final data = productDoc.data()!;
        final recipeList = data['recipe'] as List<dynamic>? ?? [];

        if (recipeList.isNotEmpty) {
          for (final recipeItem in recipeList) {
            final rawMaterialId = recipeItem['rawMaterialId'] as String;
            final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
            final rawMaterialRef = _firestore.collection('raw_materials').doc(rawMaterialId);
            batch.update(rawMaterialRef, {
              'quantity': FieldValue.increment(amountRequired * item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          batch.update(productRef, {
            'quantity': FieldValue.increment(item.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    if (order.customerId != 'walk_in') {
      final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
      batch.update(customerRef, {
        'totalPurchases': FieldValue.increment(-order.total),
        'orderCount': FieldValue.increment(-1),
        'totalDebt': FieldValue.increment(-debtDecrease),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.delete(orderRef);
    await batch.commit();
  }

  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.status == newStatus) return;

    final batch = _firestore.batch();
    final orderRef = _firestore.collection('orders').doc(order.id);

    for (final item in order.items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));

      if (productDoc.exists) {
        final data = productDoc.data()!;
        final recipeList = data['recipe'] as List<dynamic>? ?? [];

        if (newStatus == 'cancelled' && order.status != 'cancelled') {
          if (recipeList.isNotEmpty) {
            for (final recipeItem in recipeList) {
              final rawMaterialId = recipeItem['rawMaterialId'] as String;
              final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
              final rawMaterialRef = _firestore.collection('raw_materials').doc(rawMaterialId);
              batch.update(rawMaterialRef, {
                'quantity': FieldValue.increment(amountRequired * item.quantity),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } else {
            batch.update(productRef, {
              'quantity': FieldValue.increment(item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
          if (recipeList.isNotEmpty) {
            for (final recipeItem in recipeList) {
              final rawMaterialId = recipeItem['rawMaterialId'] as String;
              final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
              final rawMaterialRef = _firestore.collection('raw_materials').doc(rawMaterialId);
              batch.update(rawMaterialRef, {
                'quantity': FieldValue.increment(-(amountRequired * item.quantity)),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } else {
            batch.update(productRef, {
              'quantity': FieldValue.increment(-item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }

    batch.update(orderRef, {'status': newStatus});
    await batch.commit();
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


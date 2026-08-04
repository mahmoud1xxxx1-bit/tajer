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
    
    // Professional Triple-Shield Queue Number Architecture
    // Guarantees no duplicate order numbers on the same calendar day across merchants/employees, offline or online, even after logout or shift close!
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    int maxQueueToday = 0;

    // 1. Shield 1: Query existing orders for today from local Firestore cache (instant & works offline) and server
    try {
      final ordersSnap = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: order.merchantId)
          .get(const GetOptions(source: Source.cache))
          .catchError((_) => _firestore.collection('orders').where('merchantId', isEqualTo: order.merchantId).get());
      for (final doc in ordersSnap.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          if (!orderDate.isBefore(todayStart) && !orderDate.isAfter(todayEnd)) {
            final qNum = (data['queueNumber'] as num? ?? 0).toInt();
            if (qNum > maxQueueToday) maxQueueToday = qNum;
          }
        }
      }
    } catch (_) {}

    // Quick online server check (1.5 sec timeout) to catch recent orders created by other employees/devices today
    try {
      final serverSnap = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: order.merchantId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(milliseconds: 1500));
      for (final doc in serverSnap.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          if (!orderDate.isBefore(todayStart) && !orderDate.isAfter(todayEnd)) {
            final qNum = (data['queueNumber'] as num? ?? 0).toInt();
            if (qNum > maxQueueToday) maxQueueToday = qNum;
          }
        }
      }
    } catch (_) {}

    // 2. Shield 2: Check server daily counter document
    final counterRef = _firestore.collection('merchants').doc(order.merchantId).collection('counters').doc('daily_orders');
    try {
      final counterSnap = await counterRef.get(const GetOptions(source: Source.serverAndCache)).timeout(const Duration(milliseconds: 1500));
      if (counterSnap.exists) {
        final data = counterSnap.data()!;
        final lastDate = data['date'] as String?;
        if (lastDate == todayStr) {
          final counterNum = (data['lastNumber'] as num? ?? 0).toInt();
          if (counterNum > maxQueueToday) maxQueueToday = counterNum;
        }
      }
    } catch (_) {}

    // 3. Shield 3: Check local SharedPreferences counter
    final prefs = await SharedPreferences.getInstance();
    try {
      final lastDate = prefs.getString('queue_date_${order.merchantId}');
      if (lastDate == todayStr) {
        final prefsNum = (prefs.getInt('queue_num_${order.merchantId}') ?? 0);
        if (prefsNum > maxQueueToday) maxQueueToday = prefsNum;
      }
    } catch (_) {}

    // Master calculation: Next order number is strictly greater than the highest known order number today
    final int nextQueueNumber = maxQueueToday + 1;

    // Save synchronized state back to all storage layers
    await prefs.setString('queue_date_${order.merchantId}', todayStr);
    await prefs.setInt('queue_num_${order.merchantId}', nextQueueNumber);
    
    counterRef.set({
      'date': todayStr,
      'lastNumber': nextQueueNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) => <String, dynamic>{});
    
    final orderWithQueue = order.copyWith(queueNumber: nextQueueNumber);

    for (final item in order.items) {
      if (item.productId.isEmpty) continue;
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
            final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
            if (rmDoc.exists) {
              batch.update(rawMaterialRef, {
                'quantity': FieldValue.increment(-(amountRequired * item.quantity)),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
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

    if (order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
      final customerDoc = await customerRef.get();
      if (customerDoc.exists) {
        final debtIncrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
        batch.update(customerRef, {
          'totalPurchases': FieldValue.increment(order.total),
          'orderCount': FieldValue.increment(1),
          'totalDebt': FieldValue.increment(debtIncrease),
          'lastPurchaseDate': FieldValue.serverTimestamp(),
        });
      }
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
    final orderRef = _firestore.collection('orders').doc(order.id);

    // If order is NOT cancelled, restore inventory and subtract customer debt/purchases.
    // If order was ALREADY cancelled, its inventory & debt were already restored upon cancellation!
    if (order.status != 'cancelled') {
      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
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
              final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
              if (rmDoc.exists) {
                batch.update(rawMaterialRef, {
                  'quantity': FieldValue.increment(amountRequired * item.quantity),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
          } else {
            batch.update(productRef, {
              'quantity': FieldValue.increment(item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (order.customerId.isNotEmpty && order.customerId != 'walk_in') {
        final customerRef = _firestore.collection('customers').doc(order.customerId);
        final customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          final currentDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
          
          final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
          final actualDecrease = currentDebt >= debtDecrease ? debtDecrease : currentDebt;

          batch.update(customerRef, {
            'totalPurchases': FieldValue.increment(-order.total),
            'orderCount': FieldValue.increment(-1),
            'totalDebt': FieldValue.increment(-actualDecrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    batch.delete(orderRef);
    await batch.commit();
  }

  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.status == newStatus) return;

    final batch = _firestore.batch();
    final orderRef = _firestore.collection('orders').doc(order.id);

    // Handle inventory and customer balances upon status transitions
    if (newStatus == 'cancelled' && order.status != 'cancelled') {
      // Transitioning TO cancelled: Restore inventory & deduct from customer purchases/debt
      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
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
              final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
              if (rmDoc.exists) {
                batch.update(rawMaterialRef, {
                  'quantity': FieldValue.increment(amountRequired * item.quantity),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
          } else {
            batch.update(productRef, {
              'quantity': FieldValue.increment(item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
        final customerRef = _firestore.collection('customers').doc(order.customerId);
        final customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          final currentDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
          
          final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
          final actualDecrease = currentDebt >= debtDecrease ? debtDecrease : currentDebt;

          batch.update(customerRef, {
            'totalPurchases': FieldValue.increment(-order.total),
            'orderCount': FieldValue.increment(-1),
            'totalDebt': FieldValue.increment(-actualDecrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
      // Transitioning FROM cancelled back to active: Re-deduct inventory & re-add customer purchases/debt
      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
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
              final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
              if (rmDoc.exists) {
                batch.update(rawMaterialRef, {
                  'quantity': FieldValue.increment(-(amountRequired * item.quantity)),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
          } else {
            batch.update(productRef, {
              'quantity': FieldValue.increment(-item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
        final customerRef = _firestore.collection('customers').doc(order.customerId);
        final customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          final debtIncrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
          batch.update(customerRef, {
            'totalPurchases': FieldValue.increment(order.total),
            'orderCount': FieldValue.increment(1),
            'totalDebt': FieldValue.increment(debtIncrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    batch.update(orderRef, {'status': newStatus});
    await batch.commit();
  }

  Future<void> payCustomerDebt({
    required String merchantId,
    required String customerId,
    required double amountPaid,
    required String? shiftId,
  }) async {
    final batch = _firestore.batch();
    
    // 1. Update customer total debt
    final customerRef = _firestore.collection('customers').doc(customerId);
    final customerDoc = await customerRef.get();
    if (customerDoc.exists) {
      batch.update(customerRef, {
        'totalDebt': FieldValue.increment(-amountPaid),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 2. Fetch all unpaid credit orders for this customer to distribute the payment
    final allCreditOrdersSnapshot = await _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .where('customerId', isEqualTo: customerId)
        .where('isCredit', isEqualTo: true)
        .get();
        
    var orders = allCreditOrdersSnapshot.docs
        .map((d) => AppOrder.fromJson(d.data()))
        .where((o) => o.status != 'cancelled' && (o.total - o.paidAmount) > 0)
        .toList();
    
    orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    double remainingToDistribute = amountPaid;
    for (var order in orders) {
      if (remainingToDistribute <= 0) break;
      final unpaidForOrder = order.total - order.paidAmount;
      if (unpaidForOrder > 0) {
        final amountToApply = remainingToDistribute >= unpaidForOrder ? unpaidForOrder : remainingToDistribute;
        batch.update(_firestore.collection('orders').doc(order.id), {
          'paidAmount': FieldValue.increment(amountToApply),
        });
        remainingToDistribute -= amountToApply;
      }
    }

    // 3. Add to shift cash sales
    if (shiftId != null && shiftId.isNotEmpty) {
      final shiftRef = _firestore.collection('shifts').doc(shiftId);
      batch.update(shiftRef, {
        'cashSales': FieldValue.increment(amountPaid),
        // expectedCash will be calculated at closing based on startCash + cashSales - expenses
      });
    }

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


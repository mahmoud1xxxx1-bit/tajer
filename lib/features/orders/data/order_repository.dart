import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        final orderDate = safeParseNullableDate(data['createdAt']);
        if (orderDate != null) {
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
        final orderDate = safeParseNullableDate(data['createdAt']);
        if (orderDate != null) {
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

    // PRE-FETCH all needed products concurrently
    final productIds = order.items.map((i) => i.productId).where((id) => id.isNotEmpty).toSet().toList();
    final productFutures = productIds.map((id) => _firestore.collection('products').doc(id).get(const GetOptions(source: Source.serverAndCache)).timeout(
      const Duration(milliseconds: 1500), 
      onTimeout: () => _firestore.collection('products').doc(id).get(const GetOptions(source: Source.cache)),
    ));
    final productSnaps = await Future.wait(productFutures);
    final Map<String, DocumentSnapshot> productsCache = { for (var snap in productSnaps) if (snap.exists) snap.id: snap };
    
    // PRE-FETCH all raw materials concurrently based on recipes
    final Set<String> rawMaterialIds = {};
    for (final item in order.items) {
      if (item.productId.isEmpty) continue;
      final productSnap = productsCache[item.productId];
      if (productSnap != null) {
        final data = productSnap.data() as Map<String, dynamic>;
        final recipeList = data['recipe'] as List<dynamic>? ?? [];
        for (final recipeItem in recipeList) {
          rawMaterialIds.add(recipeItem['rawMaterialId'] as String);
        }
      }
    }
    
    final rmFutures = rawMaterialIds.map((id) => _firestore.collection('raw_materials').doc(id).get(const GetOptions(source: Source.serverAndCache)).timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => _firestore.collection('raw_materials').doc(id).get(const GetOptions(source: Source.cache)),
    ));
    final rmSnaps = await Future.wait(rmFutures);
    final Map<String, DocumentSnapshot> rawMaterialsCache = { for (var snap in rmSnaps) if (snap.exists) snap.id: snap };

    final Map<String, double> productQtyToDeduct = {};
    final Map<String, double> rmQtyToDeduct = {};
    final Map<String, String> rmNames = {};
    final Map<String, String> productNames = {};

    for (final item in order.items) {
      if (item.productId.isEmpty) continue;
      
      final productDoc = productsCache[item.productId];
      if (productDoc != null) {
        final data = productDoc.data() as Map<String, dynamic>;
        final recipeList = data['recipe'] as List<dynamic>? ?? [];
        final isManufacturedOnDemand = data['isManufacturedOnDemand'] as bool? ?? false;
        
        if (!isManufacturedOnDemand) {
          productQtyToDeduct[item.productId] = (productQtyToDeduct[item.productId] ?? 0.0) + item.quantity;
          productNames[item.productId] = data['name'] ?? item.productName;
        }
        
        if (recipeList.isNotEmpty) {
          for (final recipeItem in recipeList) {
            final rawMaterialId = recipeItem['rawMaterialId'] as String;
            final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
            final deducted = amountRequired * item.quantity;
            rmQtyToDeduct[rawMaterialId] = (rmQtyToDeduct[rawMaterialId] ?? 0.0) + deducted;
            rmNames[rawMaterialId] = data['name'] ?? item.productName;
          }
        }
      }
    }

    for (final entry in productQtyToDeduct.entries) {
      final productId = entry.key;
      final deducted = entry.value;
      final productRef = _firestore.collection('products').doc(productId);
      final productDoc = productsCache[productId];
      final data = productDoc?.data() as Map<String, dynamic>? ?? {};
      
      batch.update(productRef, {
        'quantity': FieldValue.increment(-deducted),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      final logRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
      batch.set(logRef, {
        'id': logRef.id,
        'merchantId': order.merchantId,
        'productId': productId,
        'productName': productNames[productId] ?? 'منتج',
        'changeQuantity': -deducted,
        'previousQuantity': data['quantity'] ?? 0,
        'newQuantity': (data['quantity'] as num? ?? 0) - deducted,
        'reason': 'فاتورة مبيعات #${nextQueueNumber}',
        'date': FieldValue.serverTimestamp(),
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      });
    }

    for (final entry in rmQtyToDeduct.entries) {
      final rmId = entry.key;
      final deducted = entry.value;
      final productNameForLog = rmNames[rmId] ?? '';
      final rmDoc = rawMaterialsCache[rmId];
      
      if (rmDoc != null) {
        final rawMaterialRef = _firestore.collection('raw_materials').doc(rmId);
        final rmData = rmDoc.data() as Map<String, dynamic>;
        
        batch.update(rawMaterialRef, {
          'quantity': FieldValue.increment(-deducted),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final rmLogRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
        batch.set(rmLogRef, {
          'id': rmLogRef.id,
          'merchantId': order.merchantId,
          'productId': rmId,
          'productName': rmData['name'] ?? 'مادة خام',
          'changeQuantity': -deducted,
          'previousQuantity': rmData['quantity'] ?? 0,
          'newQuantity': (rmData['quantity'] as num? ?? 0) - deducted,
          'reason': 'مباع ضمن: $productNameForLog (فاتورة #${nextQueueNumber})',
          'date': FieldValue.serverTimestamp(),
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        });
      }
    }

    if (order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
      final customerDoc = await customerRef.get(const GetOptions(source: Source.serverAndCache)).timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => customerRef.get(const GetOptions(source: Source.cache)),
      );
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
      
      double orderTax = 0.0;
      for (final item in order.items) {
        if (item.taxPercentage != null && item.taxPercentage! > 0) {
          final isInclusive = item.isTaxInclusive ?? true;
          if (isInclusive) {
            orderTax += item.total - (item.total / (1 + (item.taxPercentage! / 100)));
          } else {
            orderTax += item.total * (item.taxPercentage! / 100);
          }
        }
      }

      final updates = <String, dynamic>{
        if (orderTax > 0) 'totalTax': FieldValue.increment(orderTax),
      };

      if (order.paymentMethod == 'cash') {
        updates['cashSales'] = FieldValue.increment(order.paidAmount);
      } else if (order.paymentMethod == 'card' || order.paymentMethod == 'mada' || order.paymentMethod == 'apple_pay') {
        updates['cardTotal'] = FieldValue.increment(order.paidAmount);
      } else if (order.paymentMethod == 'transfer') {
        updates['transferTotal'] = FieldValue.increment(order.paidAmount);
      } else if (order.paymentMethod == 'split') {
        if (order.splitCashAmount != null && order.splitCashAmount! > 0) {
          updates['cashSales'] = FieldValue.increment(order.splitCashAmount!);
        }
        if (order.splitNetworkAmount != null && order.splitNetworkAmount! > 0) {
          updates['cardTotal'] = FieldValue.increment(order.splitNetworkAmount!);
        }
      }
      
      if (updates.isNotEmpty) {
        batch.update(shiftRef, updates);
      }
    }

    batch.set(orderRef, orderWithQueue.toJson());
    await batch.commit();
    return orderWithQueue;
  }

  Future<void> deleteOrder(AppOrder order) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.data()?['role'] == 'employee') {
        throw Exception('غير مصرح لك بالحذف النهائي، يمكنك الإلغاء فقط');
      }
    }

    final batch = _firestore.batch();
    final orderRef = _firestore.collection('orders').doc(order.id);

    // If order is NOT cancelled, restore inventory and subtract customer debt/purchases.
    // If order was ALREADY cancelled, its inventory & debt were already restored upon cancellation!
    if (order.status != 'cancelled') {
      final Map<String, double> productQtyToAdd = {};
      final Map<String, double> rmQtyToAdd = {};
      final Map<String, String> rmNames = {};
      final Map<String, String> productNames = {};

      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
        final productRef = _firestore.collection('products').doc(item.productId);
        final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));
        if (productDoc.exists) {
          final data = productDoc.data()!;
          final recipeList = data['recipe'] as List<dynamic>? ?? [];
          final isManufacturedOnDemand = data['isManufacturedOnDemand'] as bool? ?? false;

          if (!isManufacturedOnDemand) {
            productQtyToAdd[item.productId] = (productQtyToAdd[item.productId] ?? 0.0) + item.quantity;
            productNames[item.productId] = data['name'] ?? item.productName;
          }

          if (recipeList.isNotEmpty) {
            for (final recipeItem in recipeList) {
              final rawMaterialId = recipeItem['rawMaterialId'] as String;
              final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
              rmQtyToAdd[rawMaterialId] = (rmQtyToAdd[rawMaterialId] ?? 0.0) + (amountRequired * item.quantity);
              
              final rmRef = _firestore.collection('raw_materials').doc(rawMaterialId);
              final rmDoc = await rmRef.get(const GetOptions(source: Source.serverAndCache));
              if (rmDoc.exists) {
                rmNames[rawMaterialId] = rmDoc.data()!['name'] ?? 'مادة خام';
              }
            }
          }
        }
      }

      for (final entry in productQtyToAdd.entries) {
        final productId = entry.key;
        final added = entry.value;
        final productRef = _firestore.collection('products').doc(productId);
        final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));
        final data = productDoc.data() ?? {};
        
        batch.update(productRef, {
          'quantity': FieldValue.increment(added),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final logRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
        batch.set(logRef, {
          'id': logRef.id,
          'merchantId': order.merchantId,
          'productId': productId,
          'productName': productNames[productId] ?? 'منتج',
          'changeQuantity': added,
          'previousQuantity': data['quantity'] ?? 0,
          'newQuantity': (data['quantity'] as num? ?? 0) + added,
          'reason': 'استرجاع مخزون بسبب حذف نهائي لفاتورة #${order.queueNumber ?? order.id}',
          'date': FieldValue.serverTimestamp(),
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        });
      }

      for (final entry in rmQtyToAdd.entries) {
        final rmId = entry.key;
        final added = entry.value;
        final rawMaterialRef = _firestore.collection('raw_materials').doc(rmId);
        final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
        final rmData = rmDoc.data() ?? {};

        batch.update(rawMaterialRef, {
          'quantity': FieldValue.increment(added),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final rmLogRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
        batch.set(rmLogRef, {
          'id': rmLogRef.id,
          'merchantId': order.merchantId,
          'productId': rmId,
          'productName': rmNames[rmId] ?? 'مادة خام',
          'changeQuantity': added,
          'previousQuantity': rmData['quantity'] ?? 0,
          'newQuantity': (rmData['quantity'] as num? ?? 0) + added,
          'reason': 'استرجاع مادة بسبب حذف نهائي لفاتورة #${order.queueNumber ?? order.id}',
          'date': FieldValue.serverTimestamp(),
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        });
      }

      if (order.customerId.isNotEmpty && order.customerId != 'walk_in') {
        final customerRef = _firestore.collection('customers').doc(order.customerId);
        final customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          final currentDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
          
          final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
          // TASK 5: Allow debt to go negative (Store Credit) by removing the clamp
          final actualDecrease = debtDecrease;

          batch.update(customerRef, {
            'totalPurchases': FieldValue.increment(-order.total),
            'orderCount': FieldValue.increment(-1),
            'totalDebt': FieldValue.increment(-actualDecrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Refund the paid amount from the current open shift to prevent shortages
      if (order.paidAmount > 0) {
        final openShiftsSnap = await _firestore
            .collection('shifts')
            .where('merchantId', isEqualTo: order.merchantId)
            .where('status', isEqualTo: 'open')
            .limit(1)
            .get();
        if (openShiftsSnap.docs.isNotEmpty) {
          final shiftRef = openShiftsSnap.docs.first.reference;
          
          double orderTax = 0.0;
          for (final item in order.items) {
            if (item.taxPercentage != null && item.taxPercentage! > 0) {
              final isInclusive = item.isTaxInclusive ?? true;
              if (isInclusive) {
                orderTax += item.total - (item.total / (1 + (item.taxPercentage! / 100)));
              } else {
                orderTax += item.total * (item.taxPercentage! / 100);
              }
            }
          }

          final updates = <String, dynamic>{};
          // TASK 8: Phantom Taxes - subtract tax from shift
          if (orderTax > 0) {
            updates['totalTax'] = FieldValue.increment(-orderTax);
          }

          // TASK 4: Cross-Shift Corruption - Add to refunds instead of subtracting from sales
          if (order.paymentMethod == 'cash') {
            updates['refundsCash'] = FieldValue.increment(order.paidAmount);
          } else if (order.paymentMethod == 'card' || order.paymentMethod == 'mada' || order.paymentMethod == 'apple_pay') {
            updates['refundsCard'] = FieldValue.increment(order.paidAmount);
          } else if (order.paymentMethod == 'transfer') {
            updates['refundsTransfer'] = FieldValue.increment(order.paidAmount);
          } else if (order.paymentMethod == 'split') {
            if (order.splitCashAmount != null && order.splitCashAmount! > 0) {
              updates['refundsCash'] = FieldValue.increment(order.splitCashAmount!);
            }
            if (order.splitNetworkAmount != null && order.splitNetworkAmount! > 0) {
              updates['refundsCard'] = FieldValue.increment(order.splitNetworkAmount!);
            }
          }
          
          if (updates.isNotEmpty) {
            batch.update(shiftRef, updates);
          }
        }
      }
    }

    batch.delete(orderRef);
    await batch.commit();
  }

  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.status == newStatus) return;

    final orderRef = _firestore.collection('orders').doc(order.id);

    // 1. Transaction to prevent double cancellations (Race condition lock)
    final canProceed = await _firestore.runTransaction<bool>((transaction) async {
       final snapshot = await transaction.get(orderRef);
       if (!snapshot.exists) return false;
       final currentStatus = snapshot.data()?['status'] as String?;
       if (currentStatus == newStatus) {
         return false;
       }
       transaction.update(orderRef, {
         'status': newStatus,
         'updatedAt': FieldValue.serverTimestamp(),
       });
       return true;
    });

    if (!canProceed) return;

    final batch = _firestore.batch();

    // Handle inventory and customer balances upon status transitions
    if (newStatus == 'cancelled' && order.status != 'cancelled') {
      // Transitioning TO cancelled: Restore inventory & deduct from customer purchases/debt
      final Map<String, double> productQtyToAdd = {};
      final Map<String, double> rmQtyToAdd = {};
      final Map<String, String> rmNames = {};
      final Map<String, String> productNames = {};
      final Map<String, String> rmParentProductNames = {};

      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
        final productRef = _firestore.collection('products').doc(item.productId);
        final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));

        if (productDoc.exists) {
          final data = productDoc.data()!;
          final recipeList = data['recipe'] as List<dynamic>? ?? [];
          final isManufacturedOnDemand = data['isManufacturedOnDemand'] as bool? ?? false;

          if (!isManufacturedOnDemand) {
            productQtyToAdd[item.productId] = (productQtyToAdd[item.productId] ?? 0.0) + item.quantity;
            productNames[item.productId] = data['name'] ?? item.productName;
          }

          if (recipeList.isNotEmpty) {
            for (final recipeItem in recipeList) {
              final rawMaterialId = recipeItem['rawMaterialId'] as String;
              final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
              rmQtyToAdd[rawMaterialId] = (rmQtyToAdd[rawMaterialId] ?? 0.0) + (amountRequired * item.quantity);
              
              final rawMaterialRef = _firestore.collection('raw_materials').doc(rawMaterialId);
              final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
              if (rmDoc.exists) {
                rmNames[rawMaterialId] = rmDoc.data()!['name'] ?? 'مادة خام';
                rmParentProductNames[rawMaterialId] = data['name'] ?? item.productName;
              }
            }
          }
        }
      }

      for (final entry in productQtyToAdd.entries) {
        final productId = entry.key;
        final added = entry.value;
        final productRef = _firestore.collection('products').doc(productId);
        final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));
        final data = productDoc.data() ?? {};
        
        batch.update(productRef, {
          'quantity': FieldValue.increment(added),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final logRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
        batch.set(logRef, {
          'id': logRef.id,
          'merchantId': order.merchantId,
          'productId': productId,
          'productName': productNames[productId] ?? 'منتج',
          'changeQuantity': added,
          'previousQuantity': data['quantity'] ?? 0,
          'newQuantity': (data['quantity'] as num? ?? 0) + added,
          'reason': 'استرجاع مخزون بسبب إلغاء فاتورة #${order.queueNumber ?? order.id}',
          'date': FieldValue.serverTimestamp(),
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        });
      }

      for (final entry in rmQtyToAdd.entries) {
        final rmId = entry.key;
        final added = entry.value;
        final rawMaterialRef = _firestore.collection('raw_materials').doc(rmId);
        final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
        final rmData = rmDoc.data() ?? {};
        
        batch.update(rawMaterialRef, {
          'quantity': FieldValue.increment(added),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final rmLogRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
        batch.set(rmLogRef, {
          'id': rmLogRef.id,
          'merchantId': order.merchantId,
          'productId': rmId,
          'productName': rmNames[rmId] ?? 'مادة خام',
          'changeQuantity': added,
          'previousQuantity': rmData['quantity'] ?? 0,
          'newQuantity': (rmData['quantity'] as num? ?? 0) + added,
          'reason': 'استرجاع مادة لمنتج: ${rmParentProductNames[rmId]} (إلغاء فاتورة #${order.queueNumber ?? order.id})',
          'date': FieldValue.serverTimestamp(),
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        });
      }

      if (order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
        final customerRef = _firestore.collection('customers').doc(order.customerId);
        final customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
          // TASK 5: Allow debt to go negative (Store Credit) by removing the clamp
          final actualDecrease = debtDecrease;

          batch.update(customerRef, {
            'totalPurchases': FieldValue.increment(-order.total),
            'orderCount': FieldValue.increment(-1),
            'totalDebt': FieldValue.increment(-actualDecrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Refund the paid amount from the current open shift to prevent shortages
      if (order.paidAmount > 0) {
        final openShiftsSnap = await _firestore
            .collection('shifts')
            .where('merchantId', isEqualTo: order.merchantId)
            .where('status', isEqualTo: 'open')
            .limit(1)
            .get();
        if (openShiftsSnap.docs.isNotEmpty) {
          final shiftRef = openShiftsSnap.docs.first.reference;

          double orderTax = 0.0;
          for (final item in order.items) {
            if (item.taxPercentage != null && item.taxPercentage! > 0) {
              final isInclusive = item.isTaxInclusive ?? true;
              if (isInclusive) {
                orderTax += item.total - (item.total / (1 + (item.taxPercentage! / 100)));
              } else {
                orderTax += item.total * (item.taxPercentage! / 100);
              }
            }
          }

          final updates = <String, dynamic>{};
          // TASK 8: Phantom Taxes - subtract tax from shift
          if (orderTax > 0) {
            updates['totalTax'] = FieldValue.increment(-orderTax);
          }

          // TASK 4: Cross-Shift Corruption - Add to refunds instead of subtracting from sales
          if (order.paymentMethod == 'cash') {
            updates['refundsCash'] = FieldValue.increment(order.paidAmount);
          } else if (order.paymentMethod == 'card' || order.paymentMethod == 'mada' || order.paymentMethod == 'apple_pay') {
            updates['refundsCard'] = FieldValue.increment(order.paidAmount);
          } else if (order.paymentMethod == 'transfer') {
            updates['refundsTransfer'] = FieldValue.increment(order.paidAmount);
          } else if (order.paymentMethod == 'split') {
            if (order.splitCashAmount != null && order.splitCashAmount! > 0) {
              updates['refundsCash'] = FieldValue.increment(order.splitCashAmount!);
            }
            if (order.splitNetworkAmount != null && order.splitNetworkAmount! > 0) {
              updates['refundsCard'] = FieldValue.increment(order.splitNetworkAmount!);
            }
          }
          
          if (updates.isNotEmpty) {
            batch.update(shiftRef, updates);
          }
        }
      }
    } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
      // Transitioning FROM cancelled back to active: Re-deduct inventory & re-add customer purchases/debt
      final Map<String, double> productQtyToDeduct = {};
      final Map<String, double> rmQtyToDeduct = {};
      final Map<String, String> rmNames = {};
      final Map<String, String> productNames = {};
      final Map<String, String> rmParentProductNames = {};

      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
        final productRef = _firestore.collection('products').doc(item.productId);
        final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));

        if (productDoc.exists) {
          final data = productDoc.data()!;
          final recipeList = data['recipe'] as List<dynamic>? ?? [];
          final isManufacturedOnDemand = data['isManufacturedOnDemand'] as bool? ?? false;

          if (!isManufacturedOnDemand) {
            productQtyToDeduct[item.productId] = (productQtyToDeduct[item.productId] ?? 0.0) + item.quantity;
            productNames[item.productId] = data['name'] ?? item.productName;
          }

          if (recipeList.isNotEmpty) {
            for (final recipeItem in recipeList) {
              final rawMaterialId = recipeItem['rawMaterialId'] as String;
              final amountRequired = (recipeItem['amountRequired'] as num).toDouble();
              rmQtyToDeduct[rawMaterialId] = (rmQtyToDeduct[rawMaterialId] ?? 0.0) + (amountRequired * item.quantity);
              
              final rawMaterialRef = _firestore.collection('raw_materials').doc(rawMaterialId);
              final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
              if (rmDoc.exists) {
                rmNames[rawMaterialId] = rmDoc.data()!['name'] ?? 'مادة خام';
                rmParentProductNames[rawMaterialId] = data['name'] ?? item.productName;
              }
            }
          }
        }
      }

      for (final entry in productQtyToDeduct.entries) {
        final productId = entry.key;
        final deducted = entry.value;
        final productRef = _firestore.collection('products').doc(productId);
        final productDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));
        final data = productDoc.data() ?? {};
        
        batch.update(productRef, {
          'quantity': FieldValue.increment(-deducted),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final logRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
        batch.set(logRef, {
          'id': logRef.id,
          'merchantId': order.merchantId,
          'productId': productId,
          'productName': productNames[productId] ?? 'منتج',
          'changeQuantity': -deducted,
          'previousQuantity': data['quantity'] ?? 0,
          'newQuantity': (data['quantity'] as num? ?? 0) - deducted,
          'reason': 'خصم مخزون بسبب التراجع عن إلغاء الفاتورة #${order.queueNumber ?? order.id}',
          'date': FieldValue.serverTimestamp(),
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        });
      }

      for (final entry in rmQtyToDeduct.entries) {
        final rmId = entry.key;
        final deducted = entry.value;
        final rawMaterialRef = _firestore.collection('raw_materials').doc(rmId);
        final rmDoc = await rawMaterialRef.get(const GetOptions(source: Source.serverAndCache));
        final rmData = rmDoc.data() ?? {};
        
        batch.update(rawMaterialRef, {
          'quantity': FieldValue.increment(-deducted),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final rmLogRef = _firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
        batch.set(rmLogRef, {
          'id': rmLogRef.id,
          'merchantId': order.merchantId,
          'productId': rmId,
          'productName': rmNames[rmId] ?? 'مادة خام',
          'changeQuantity': -deducted,
          'previousQuantity': rmData['quantity'] ?? 0,
          'newQuantity': (rmData['quantity'] as num? ?? 0) - deducted,
          'reason': 'خصم مادة لمنتج: ${rmParentProductNames[rmId]} (التراجع عن إلغاء فاتورة #${order.queueNumber ?? order.id})',
          'date': FieldValue.serverTimestamp(),
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        });
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
    required String paymentMethod, // 'cash', 'card', 'transfer'
  }) async {
    if (amountPaid <= 0) return;

    // Concurrency Lock: Read current debt using a transaction
    final canProceed = await _firestore.runTransaction<bool>((transaction) async {
      final customerRef = _firestore.collection('customers').doc(customerId);
      final customerDoc = await transaction.get(customerRef);
      if (!customerDoc.exists) return false;

      final currentDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
      if (amountPaid > currentDebt) {
        throw Exception('مبلغ السداد لا يمكن أن يتجاوز الدين المستحق.');
      }
      
      transaction.update(customerRef, {
        'totalDebt': FieldValue.increment(-amountPaid),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (!canProceed) return;

    final batch = _firestore.batch();


    // 2. Fetch all unpaid credit orders for this customer to distribute the payment
    final allCreditOrdersSnapshot = await _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .where('customerId', isEqualTo: customerId)
        .where('isCredit', isEqualTo: true)
        .get();
        
    var orders = allCreditOrdersSnapshot.docs
        .map((d) {
        final data = d.data();
        data['id'] = d.id;
        return AppOrder.fromJson(data);
      })
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

    // 3. Add to shift debt collections
    if (shiftId != null && shiftId.isNotEmpty) {
      final shiftRef = _firestore.collection('shifts').doc(shiftId);
      if (paymentMethod == 'cash') {
        batch.update(shiftRef, {
          'debtCollectionsCash': FieldValue.increment(amountPaid),
        });
      } else if (paymentMethod == 'card' || paymentMethod == 'mada') {
        batch.update(shiftRef, {
          'debtCollectionsCard': FieldValue.increment(amountPaid),
        });
      } else if (paymentMethod == 'transfer') {
        batch.update(shiftRef, {
          'debtCollectionsTransfer': FieldValue.increment(amountPaid),
        });
      }
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
  
  return repository.queryOrders(appUser.merchantId ?? appUser.id)
      .snapshots()
      .map(
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


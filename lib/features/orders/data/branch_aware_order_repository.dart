import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../branches/data/order_branch_inventory_service.dart';
import '../domain/order.dart';
import 'order_repository.dart';

/// Multi-branch implementation that preserves the v1.0.107 accounting formulas
/// while changing only the inventory/shift scope from merchant-wide to branch.
class BranchAwareOrderRepository extends OrderRepository {
  final FirebaseFirestore firestore;

  BranchAwareOrderRepository(this.firestore) : super(firestore);

  Future<String> _selectedBranch(String merchantId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('selected_branch_$merchantId')?.trim();
    return value == null || value.isEmpty ? 'main' : value;
  }

  @override
  Future<AppOrder> createOrder(AppOrder order, {String? shiftId}) async {
    final branchId = await _selectedBranch(order.merchantId);
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    final dateKey = 'queue_date_${order.merchantId}_$branchId';
    final numKey = 'queue_num_${order.merchantId}_$branchId';
    final localNumber =
        prefs.getString(dateKey) == date ? (prefs.getInt(numKey) ?? 0) : 0;

    final orderRef = firestore.collection('orders').doc(order.id);
    final counterRef = firestore
        .collection('merchants')
        .doc(order.merchantId)
        .collection('counters')
        .doc('daily_orders_$branchId');

    final createdOrder = await firestore.runTransaction<AppOrder>((tx) async {
      final existingOrder = await tx.get(orderRef);
      if (existingOrder.exists && existingOrder.data() != null) {
        final existingData = Map<String, dynamic>.from(existingOrder.data()!);
        existingData['id'] = existingOrder.id;
        return AppOrder.fromJson(existingData);
      }

      final counterSnap = await tx.get(counterRef);
      final counterData = counterSnap.data();
      final current = counterData?['date'] == date
          ? (counterData?['lastNumber'] as num?)?.toInt() ?? 0
          : 0;
      final queueNumber = (current > localNumber ? current : localNumber) + 1;
      final orderWithQueue = order.copyWith(
        branchId: branchId,
        shiftId: shiftId,
        queueNumber: queueNumber,
      );
      final orderWithCostSnapshot =
          await _attachHistoricalCosts(tx, orderWithQueue);

      DocumentReference<Map<String, dynamic>>? customerRef;
      DocumentSnapshot<Map<String, dynamic>>? customerDoc;
      if (orderWithQueue.customerId != 'walk_in' &&
          orderWithQueue.customerId.isNotEmpty) {
        customerRef =
            firestore.collection('customers').doc(orderWithQueue.customerId);
        customerDoc = await tx.get(customerRef);
        if (customerDoc.exists && customerDoc.data() != null) {
          final customerBranchId =
              customerDoc.data()?['branchId']?.toString() ?? 'main';
          if (customerBranchId != branchId) {
            throw Exception('Customer account belongs to a different branch.');
          }
        }
      }

      DocumentReference<Map<String, dynamic>>? shiftRef;
      if (shiftId != null && shiftId.isNotEmpty) {
        shiftRef = firestore.collection('shifts').doc(shiftId);
        final shiftSnap = await tx.get(shiftRef);
        if (!shiftSnap.exists) {
          throw Exception('Shift not found');
        }
        final shiftBranchId =
            shiftSnap.data()?['branchId']?.toString() ?? 'main';
        final shiftStatus = shiftSnap.data()?['status']?.toString();
        if (shiftBranchId != branchId || shiftStatus != 'open') {
          throw Exception('Order branch does not match the active shift');
        }
      }

      await OrderBranchInventoryService(firestore).applySaleInTransaction(
        tx,
        orderWithCostSnapshot,
        queueNumber: queueNumber,
      );

      tx.set(
          counterRef,
          {
            'date': date,
            'lastNumber': queueNumber,
            'branchId': branchId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (customerRef != null && customerDoc?.exists == true) {
        final debtIncrease = orderWithQueue.isCredit
            ? (orderWithQueue.total - orderWithQueue.paidAmount)
            : 0.0;
        tx.update(customerRef, {
          'totalPurchases': FieldValue.increment(orderWithQueue.total),
          'orderCount': FieldValue.increment(1),
          'totalDebt': FieldValue.increment(debtIncrease),
          'lastPurchaseDate': FieldValue.serverTimestamp(),
        });
      }

      if (shiftRef != null) {
        final updates = _saleShiftUpdates(orderWithCostSnapshot);
        if (updates.isNotEmpty) tx.update(shiftRef, updates);
      }

      tx.set(orderRef, orderWithCostSnapshot.toJson());
      return orderWithCostSnapshot;
    });

    await prefs.setString(dateKey, date);
    if (createdOrder.queueNumber != null) {
      await prefs.setInt(numKey, createdOrder.queueNumber!);
    }
    return createdOrder;
  }

  Future<AppOrder> _attachHistoricalCosts(
    Transaction tx,
    AppOrder order,
  ) async {
    final productIds = order.items
        .map((item) => item.productId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (productIds.isEmpty) return order;

    final products = <String, Map<String, dynamic>>{};
    final rawMaterialIds = <String>{};
    for (final productId in productIds) {
      final snap =
          await tx.get(firestore.collection('products').doc(productId));
      if (!snap.exists || snap.data() == null) continue;
      final data = snap.data()!;
      products[productId] = data;
      for (final raw in (data['recipe'] as List<dynamic>? ?? const [])) {
        final map = Map<String, dynamic>.from(raw as Map);
        final rawId = map['rawMaterialId']?.toString();
        if (rawId != null && rawId.isNotEmpty) rawMaterialIds.add(rawId);
      }
    }

    final costIds = {...productIds, ...rawMaterialIds};
    final costs = <String, double>{};
    for (final id in costIds) {
      final snap = await tx.get(firestore
          .collection('merchants')
          .doc(order.merchantId)
          .collection('product_costs')
          .doc(id));
      final value = snap.data()?['costPrice'];
      if (value is num && value >= 0) costs[id] = value.toDouble();
    }

    final items = order.items.map((item) {
      final product = products[item.productId];
      final isManufacturedOnDemand = item.isManufacturedOnDemand ||
          (product?['isManufacturedOnDemand'] as bool? ?? false);
      double? unitCost = costs[item.productId] ?? item.costPrice;

      if (isManufacturedOnDemand && product != null) {
        var recipeComplete = true;
        var recipeUnitCost = 0.0;
        final recipe = product['recipe'] as List<dynamic>? ?? const [];
        if (recipe.isEmpty) recipeComplete = false;
        for (final raw in recipe) {
          final map = Map<String, dynamic>.from(raw as Map);
          final rawId = map['rawMaterialId']?.toString() ?? '';
          final amount = (map['amountRequired'] as num?)?.toDouble();
          final rawCost = costs[rawId];
          if (rawId.isEmpty ||
              amount == null ||
              amount <= 0 ||
              rawCost == null) {
            recipeComplete = false;
            continue;
          }
          recipeUnitCost += rawCost * amount;
        }
        unitCost = recipeComplete ? recipeUnitCost : unitCost;
      }

      return item.copyWith(
        costPrice: unitCost,
        isManufacturedOnDemand: isManufacturedOnDemand,
      );
    }).toList();

    return order.copyWith(items: items);
  }

  Map<String, dynamic> _saleShiftUpdates(AppOrder order) {
    final updates = <String, dynamic>{};
    final orderTax = _orderTax(order);
    if (orderTax > 0) updates['totalTax'] = FieldValue.increment(orderTax);

    switch (order.paymentMethod) {
      case 'cash':
        updates['cashSales'] = FieldValue.increment(order.paidAmount);
        break;
      case 'card':
      case 'mada':
      case 'apple_pay':
        updates['cardTotal'] = FieldValue.increment(order.paidAmount);
        break;
      case 'transfer':
        updates['transferTotal'] = FieldValue.increment(order.paidAmount);
        break;
      case 'split':
        if ((order.splitCashAmount ?? 0) > 0) {
          updates['cashSales'] = FieldValue.increment(order.splitCashAmount!);
        }
        if ((order.splitNetworkAmount ?? 0) > 0) {
          updates['cardTotal'] =
              FieldValue.increment(order.splitNetworkAmount!);
        }
        break;
    }
    return updates;
  }

  double _orderTax(AppOrder order) {
    double orderTax = 0.0;
    for (final item in order.items) {
      final tax = item.taxPercentage ?? 0.0;
      if (tax <= 0) continue;
      final inclusive = item.isTaxInclusive ?? true;
      orderTax += inclusive
          ? item.total - (item.total / (1 + tax / 100))
          : item.total * (tax / 100);
    }
    return orderTax;
  }

  @override
  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.status == newStatus) return;

    final orderRef = firestore.collection('orders').doc(order.id);
    await firestore.runTransaction<void>((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists || snap.data() == null) return;

      final data = snap.data()!;
      final canonicalData = Map<String, dynamic>.from(data);
      canonicalData['id'] = snap.id;
      final canonicalOrder = AppOrder.fromJson(canonicalData);
      final currentStatus = data['status']?.toString() ?? 'pending';
      if (currentStatus == newStatus) return;
      if (currentStatus != order.status || data['statusTransition'] != null) {
        throw Exception(
            'Order status changed on another device. Please refresh.');
      }
      if (newStatus == 'cancelled' &&
          canonicalOrder.isCredit &&
          canonicalOrder.paidAmount > 0.01) {
        throw Exception(
          'A paid or partially-paid credit invoice cannot be cancelled until its debt payment is reversed.',
        );
      }

      DocumentReference<Map<String, dynamic>>? refundShiftRef;
      Map<String, dynamic>? refundShiftUpdates;
      if (newStatus == 'cancelled' &&
          canonicalOrder.status != 'cancelled' &&
          canonicalOrder.paidAmount > 0 &&
          canonicalOrder.shiftId != null &&
          canonicalOrder.shiftId!.isNotEmpty) {
        final shiftRef =
            firestore.collection('shifts').doc(canonicalOrder.shiftId);
        final shiftSnap = await tx.get(shiftRef);
        final shiftData = shiftSnap.data();
        if (!shiftSnap.exists ||
            shiftData == null ||
            shiftData['merchantId'] != canonicalOrder.merchantId ||
            (shiftData['branchId']?.toString() ?? 'main') !=
                canonicalOrder.branchId) {
          throw Exception(
              'Order refund shift does not match the order merchant and branch.');
        }
        refundShiftRef = shiftRef;
        final updates = _refundShiftUpdates(canonicalOrder);
        if (updates.isNotEmpty) refundShiftUpdates = updates;
      }

      if (newStatus == 'cancelled' && canonicalOrder.status != 'cancelled') {
        await OrderBranchInventoryService(firestore)
            .restoreForCancellationInTransaction(tx, canonicalOrder);
      } else if (canonicalOrder.status == 'cancelled' &&
          newStatus != 'cancelled') {
        await OrderBranchInventoryService(firestore)
            .reDeductAfterCancellationReversalInTransaction(tx, canonicalOrder);
      }

      if (newStatus == 'cancelled' && canonicalOrder.status != 'cancelled') {
        if (canonicalOrder.customerId != 'walk_in' &&
            canonicalOrder.customerId.isNotEmpty) {
          final customerRef =
              firestore.collection('customers').doc(canonicalOrder.customerId);
          final debtDecrease = canonicalOrder.isCredit
              ? (canonicalOrder.total - canonicalOrder.paidAmount)
              : 0.0;
          tx.update(customerRef, {
            'totalPurchases': FieldValue.increment(-canonicalOrder.total),
            'orderCount': FieldValue.increment(-1),
            'totalDebt': FieldValue.increment(-debtDecrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        if (refundShiftRef != null && refundShiftUpdates != null) {
          tx.update(refundShiftRef, refundShiftUpdates);
        }
      } else if (canonicalOrder.status == 'cancelled' &&
          newStatus != 'cancelled') {
        if (canonicalOrder.customerId != 'walk_in' &&
            canonicalOrder.customerId.isNotEmpty) {
          final customerRef =
              firestore.collection('customers').doc(canonicalOrder.customerId);
          final debtIncrease = canonicalOrder.isCredit
              ? (canonicalOrder.total - canonicalOrder.paidAmount)
              : 0.0;
          tx.update(customerRef, {
            'totalPurchases': FieldValue.increment(canonicalOrder.total),
            'orderCount': FieldValue.increment(1),
            'totalDebt': FieldValue.increment(debtIncrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      tx.update(orderRef, {
        'status': newStatus,
        'statusTransition': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Map<String, dynamic> _refundShiftUpdates(AppOrder order) {
    final updates = <String, dynamic>{};
    final orderTax = _orderTax(order);
    if (orderTax > 0) updates['totalTax'] = FieldValue.increment(-orderTax);

    switch (order.paymentMethod) {
      case 'cash':
        updates['refundsCash'] = FieldValue.increment(order.paidAmount);
        break;
      case 'card':
      case 'mada':
      case 'apple_pay':
        updates['refundsCard'] = FieldValue.increment(order.paidAmount);
        break;
      case 'transfer':
        updates['refundsTransfer'] = FieldValue.increment(order.paidAmount);
        break;
      case 'split':
        if ((order.splitCashAmount ?? 0) > 0) {
          updates['refundsCash'] = FieldValue.increment(order.splitCashAmount!);
        }
        if ((order.splitNetworkAmount ?? 0) > 0) {
          updates['refundsCard'] =
              FieldValue.increment(order.splitNetworkAmount!);
        }
        break;
    }
    return updates;
  }

  @override
  Future<void> payCustomerDebt({
    required String merchantId,
    required String customerId,
    required double amountPaid,
    required String? shiftId,
    required String paymentMethod,
  }) async {
    if (amountPaid <= 0) return;

    final branchId = await _selectedBranch(merchantId);
    final creditOrdersSnapshot = await firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .where('customerId', isEqualTo: customerId)
        .where('isCredit', isEqualTo: true)
        .get();

    final orderRefs = creditOrdersSnapshot.docs
        .where(
            (doc) => (doc.data()['branchId']?.toString() ?? 'main') == branchId)
        .map((doc) => doc.reference)
        .toList();
    final paymentRef = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('customer_debt_payments')
        .doc();

    await firestore.runTransaction((transaction) async {
      final customerRef = firestore.collection('customers').doc(customerId);
      final customerDoc = await transaction.get(customerRef);
      if (!customerDoc.exists || customerDoc.data() == null) {
        throw Exception('العميل غير موجود.');
      }

      final currentDebt =
          (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
      final customerBranchId =
          customerDoc.data()?['branchId']?.toString() ?? 'main';
      if (customerBranchId != branchId) {
        throw Exception('لا يمكن تحصيل دين عميل تابع لفرع مختلف.');
      }
      if (amountPaid > currentDebt) {
        throw Exception('مبلغ السداد لا يمكن أن يتجاوز الدين المستحق.');
      }

      DocumentReference<Map<String, dynamic>>? activeShiftRef;
      if (shiftId != null && shiftId.isNotEmpty) {
        activeShiftRef = firestore.collection('shifts').doc(shiftId);
        final shiftDoc = await transaction.get(activeShiftRef);
        if (!shiftDoc.exists || shiftDoc.data() == null) {
          throw Exception('الوردية المرتبطة بالسداد غير موجودة.');
        }
        final shiftData = shiftDoc.data()!;
        final shiftBranchId = shiftData['branchId']?.toString() ?? 'main';
        if (shiftBranchId != branchId ||
            shiftData['status']?.toString() != 'open' ||
            shiftData['endTime'] != null) {
          throw Exception(
              'لا يمكن تسجيل التحصيل على وردية مغلقة أو فرع مختلف.');
        }
      }

      final liveOrders = <MapEntry<DocumentReference<Map<String, dynamic>>,
          Map<String, dynamic>>>[];
      for (final ref in orderRefs) {
        final snap = await transaction.get(ref);
        if (!snap.exists || snap.data() == null) continue;
        final data = snap.data()!;
        final orderBranchId = data['branchId']?.toString() ?? 'main';
        if (orderBranchId != branchId) continue;
        if (data['status']?.toString() == 'cancelled') continue;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        final paid = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
        if (total - paid > 0.0001) liveOrders.add(MapEntry(ref, data));
      }

      liveOrders.sort((a, b) {
        DateTime readDate(Map<String, dynamic> data) {
          final value = data['createdAt'];
          if (value is Timestamp) return value.toDate();
          if (value is String) {
            return DateTime.tryParse(value) ??
                DateTime.fromMillisecondsSinceEpoch(0);
          }
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        return readDate(a.value).compareTo(readDate(b.value));
      });

      var remaining = amountPaid;
      final allocations = <Map<String, dynamic>>[];
      for (final entry in liveOrders) {
        if (remaining <= 0.0001) break;
        final total = (entry.value['total'] as num?)?.toDouble() ?? 0.0;
        final alreadyPaid =
            (entry.value['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final outstanding = total - alreadyPaid;
        if (outstanding <= 0) continue;
        final applied = remaining >= outstanding ? outstanding : remaining;
        transaction
            .update(entry.key, {'paidAmount': FieldValue.increment(applied)});
        allocations.add({'orderId': entry.key.id, 'amount': applied});
        remaining -= applied;
      }

      if (remaining > 0.0001) {
        throw Exception(
            'تعذر توزيع مبلغ السداد بالكامل على الفواتير الحالية. حدّث الصفحة وحاول مرة أخرى.');
      }

      transaction.update(customerRef, {
        'totalDebt': FieldValue.increment(-amountPaid),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (activeShiftRef != null) {
        if (paymentMethod == 'cash') {
          transaction.update(activeShiftRef,
              {'debtCollectionsCash': FieldValue.increment(amountPaid)});
        } else if (paymentMethod == 'card' || paymentMethod == 'mada') {
          transaction.update(activeShiftRef,
              {'debtCollectionsCard': FieldValue.increment(amountPaid)});
        } else if (paymentMethod == 'transfer') {
          transaction.update(activeShiftRef,
              {'debtCollectionsTransfer': FieldValue.increment(amountPaid)});
        }
      }

      transaction.set(paymentRef, {
        'id': paymentRef.id,
        'merchantId': merchantId,
        'customerId': customerId,
        'branchId': branchId,
        'shiftId': shiftId,
        'amount': amountPaid,
        'paymentMethod': paymentMethod,
        'allocations': allocations,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _guardPaidCreditInvoiceMutation(AppOrder order, String targetAction) {
    if (!order.isCredit || order.paidAmount <= 0.01) return;
    throw Exception(
      'A paid or partially-paid credit invoice cannot be $targetAction until its debt payment is reversed.',
    );
  }

  @override
  Future<void> deleteOrder(AppOrder order) async {
    _guardPaidCreditInvoiceMutation(order, 'حذف');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.data()?['role'] == 'employee') {
        throw Exception('غير مصرح لك بالحذف النهائي، يمكنك الإلغاء فقط');
      }
    }

    if (order.status != 'cancelled') {
      await OrderBranchInventoryService(firestore).restoreForDeletion(order);
    }
    try {
      final batch = firestore.batch();
      if (order.status != 'cancelled' &&
          order.customerId != 'walk_in' &&
          order.customerId.isNotEmpty) {
        final customerRef =
            firestore.collection('customers').doc(order.customerId);
        final debtDecrease =
            order.isCredit ? (order.total - order.paidAmount) : 0.0;
        batch.update(customerRef, {
          'totalPurchases': FieldValue.increment(-order.total),
          'orderCount': FieldValue.increment(-1),
          'totalDebt': FieldValue.increment(-debtDecrease),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.delete(firestore.collection('orders').doc(order.id));
      await batch.commit();
    } catch (_) {
      if (order.status != 'cancelled') {
        await OrderBranchInventoryService(firestore)
            .reDeductAfterCancellationReversal(order);
      }
      rethrow;
    }
  }
}

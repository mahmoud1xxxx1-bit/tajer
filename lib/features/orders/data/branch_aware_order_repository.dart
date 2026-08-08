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

  Future<int> _nextBranchQueueNumber(String merchantId, String branchId) async {
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    final dateKey = 'queue_date_${merchantId}_$branchId';
    final numKey = 'queue_num_${merchantId}_$branchId';

    var localNumber = prefs.getString(dateKey) == date ? (prefs.getInt(numKey) ?? 0) : 0;
    final counterRef = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('counters')
        .doc('daily_orders_$branchId');

    try {
      localNumber = await firestore.runTransaction<int>((tx) async {
        final snap = await tx.get(counterRef);
        final data = snap.data();
        final current = data?['date'] == date
            ? (data?['lastNumber'] as num?)?.toInt() ?? 0
            : 0;
        final next = (current > localNumber ? current : localNumber) + 1;
        tx.set(counterRef, {
          'date': date,
          'lastNumber': next,
          'branchId': branchId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return next;
      });
    } catch (_) {
      localNumber += 1;
    }

    await prefs.setString(dateKey, date);
    await prefs.setInt(numKey, localNumber);
    return localNumber;
  }

  @override
  Future<AppOrder> createOrder(AppOrder order, {String? shiftId}) async {
    final branchId = await _selectedBranch(order.merchantId);
    final queueNumber = await _nextBranchQueueNumber(order.merchantId, branchId);
    final orderWithQueue = order.copyWith(branchId: branchId, queueNumber: queueNumber);

    await OrderBranchInventoryService(firestore)
        .applySale(orderWithQueue, queueNumber: queueNumber);

    final batch = firestore.batch();
    final orderRef = firestore.collection('orders').doc(orderWithQueue.id);

    if (orderWithQueue.customerId != 'walk_in' && orderWithQueue.customerId.isNotEmpty) {
      final customerRef = firestore.collection('customers').doc(orderWithQueue.customerId);
      final customerDoc = await customerRef.get(const GetOptions(source: Source.serverAndCache));
      if (customerDoc.exists) {
        final debtIncrease = orderWithQueue.isCredit
            ? (orderWithQueue.total - orderWithQueue.paidAmount)
            : 0.0;
        batch.update(customerRef, {
          'totalPurchases': FieldValue.increment(orderWithQueue.total),
          'orderCount': FieldValue.increment(1),
          'totalDebt': FieldValue.increment(debtIncrease),
          'lastPurchaseDate': FieldValue.serverTimestamp(),
        });
      }
    }

    if (shiftId != null && shiftId.isNotEmpty) {
      final shiftRef = firestore.collection('shifts').doc(shiftId);
      final shiftSnap = await shiftRef.get(const GetOptions(source: Source.serverAndCache));
      if (!shiftSnap.exists) {
        await OrderBranchInventoryService(firestore).restoreForDeletion(orderWithQueue);
        throw Exception('Shift not found');
      }
      final shiftBranchId = shiftSnap.data()?['branchId']?.toString() ?? 'main';
      final shiftStatus = shiftSnap.data()?['status']?.toString();
      if (shiftBranchId != branchId || shiftStatus != 'open') {
        await OrderBranchInventoryService(firestore).restoreForDeletion(orderWithQueue);
        throw Exception('Order branch does not match the active shift');
      }
      final updates = _saleShiftUpdates(orderWithQueue);
      if (updates.isNotEmpty) batch.update(shiftRef, updates);
    }

    batch.set(orderRef, orderWithQueue.toJson());
    try {
      await batch.commit();
      return orderWithQueue;
    } catch (_) {
      await OrderBranchInventoryService(firestore).restoreForDeletion(orderWithQueue);
      rethrow;
    }
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
          updates['cardTotal'] = FieldValue.increment(order.splitNetworkAmount!);
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

  Future<bool> _claimStatusTransition(AppOrder order, String newStatus) {
    final orderRef = firestore.collection('orders').doc(order.id);
    return firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) return false;
      final data = snap.data()!;
      final currentStatus = data['status']?.toString() ?? 'pending';
      if (currentStatus == newStatus) return false;
      if (currentStatus != order.status || data['statusTransition'] != null) {
        throw Exception('Order status changed on another device. Please refresh.');
      }
      tx.update(orderRef, {
        'statusTransition': {
          'from': currentStatus,
          'to': newStatus,
          'startedAt': FieldValue.serverTimestamp(),
        },
      });
      return true;
    });
  }

  Future<void> _clearStatusTransition(String orderId) async {
    await firestore.collection('orders').doc(orderId).update({
      'statusTransition': FieldValue.delete(),
    });
  }

  void _guardPaidCreditInvoiceMutation(AppOrder order, String targetAction) {
    if (!order.isCredit || order.paidAmount <= 0.01) return;
    throw Exception(
      'لا يمكن $targetAction فاتورة آجلة تم تحصيل مبلغ منها. يجب معالجة/عكس التحصيل أولاً حفاظاً على تطابق دين العميل وسجل الوردية. '
      'A paid or partially-paid credit invoice cannot be $targetAction until its debt payment is reversed.',
    );
  }

  @override
  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.status == newStatus) return;
    if (newStatus == 'cancelled' && order.status != 'cancelled') {
      _guardPaidCreditInvoiceMutation(order, 'إلغاء');
    }

    final claimed = await _claimStatusTransition(order, newStatus);
    if (!claimed) return;

    var inventoryChanged = false;
    try {
      if (newStatus == 'cancelled' && order.status != 'cancelled') {
        await OrderBranchInventoryService(firestore).restoreForCancellation(order);
        inventoryChanged = true;
      } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
        await OrderBranchInventoryService(firestore).reDeductAfterCancellationReversal(order);
        inventoryChanged = true;
      }
      await _applyStatusFinancials(order, newStatus);
    } catch (_) {
      if (inventoryChanged) {
        if (newStatus == 'cancelled' && order.status != 'cancelled') {
          await OrderBranchInventoryService(firestore).reDeductAfterCancellationReversal(order);
        } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
          await OrderBranchInventoryService(firestore).restoreForCancellation(order);
        }
      }
      await _clearStatusTransition(order.id).catchError((_) {});
      rethrow;
    }
  }

  Future<void> _applyStatusFinancials(AppOrder order, String newStatus) async {
    final orderRef = firestore.collection('orders').doc(order.id);
    final batch = firestore.batch();

    if (newStatus == 'cancelled' && order.status != 'cancelled') {
      if (order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
        final customerRef = firestore.collection('customers').doc(order.customerId);
        final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
        batch.update(customerRef, {
          'totalPurchases': FieldValue.increment(-order.total),
          'orderCount': FieldValue.increment(-1),
          'totalDebt': FieldValue.increment(-debtDecrease),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await _appendRefundToOpenBranchShift(batch, order);
    } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
      if (order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
        final customerRef = firestore.collection('customers').doc(order.customerId);
        final debtIncrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
        batch.update(customerRef, {
          'totalPurchases': FieldValue.increment(order.total),
          'orderCount': FieldValue.increment(1),
          'totalDebt': FieldValue.increment(debtIncrease),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.update(orderRef, {
      'status': newStatus,
      'statusTransition': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _appendRefundToOpenBranchShift(WriteBatch batch, AppOrder order) async {
    if (order.paidAmount <= 0) return;
    final snap = await firestore
        .collection('shifts')
        .where('merchantId', isEqualTo: order.merchantId)
        .where('status', isEqualTo: 'open')
        .get();
    final matching = snap.docs.where((doc) {
      final value = doc.data()['branchId']?.toString() ?? 'main';
      return value == order.branchId;
    }).toList();
    if (matching.isEmpty) return;

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
          updates['refundsCard'] = FieldValue.increment(order.splitNetworkAmount!);
        }
        break;
    }
    if (updates.isNotEmpty) batch.update(matching.first.reference, updates);
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

    final orderRefs = creditOrdersSnapshot.docs.map((doc) => doc.reference).toList();
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

      final currentDebt = (customerDoc.data()?['totalDebt'] as num?)?.toDouble() ?? 0.0;
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
          throw Exception('لا يمكن تسجيل التحصيل على وردية مغلقة أو فرع مختلف.');
        }
      }

      final liveOrders = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>[];
      for (final ref in orderRefs) {
        final snap = await transaction.get(ref);
        if (!snap.exists || snap.data() == null) continue;
        final data = snap.data()!;
        if (data['status']?.toString() == 'cancelled') continue;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        final paid = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
        if (total - paid > 0.0001) liveOrders.add(MapEntry(ref, data));
      }

      liveOrders.sort((a, b) {
        DateTime readDate(Map<String, dynamic> data) {
          final value = data['createdAt'];
          if (value is Timestamp) return value.toDate();
          if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
        return readDate(a.value).compareTo(readDate(b.value));
      });

      var remaining = amountPaid;
      final allocations = <Map<String, dynamic>>[];
      for (final entry in liveOrders) {
        if (remaining <= 0.0001) break;
        final total = (entry.value['total'] as num?)?.toDouble() ?? 0.0;
        final alreadyPaid = (entry.value['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final outstanding = total - alreadyPaid;
        if (outstanding <= 0) continue;
        final applied = remaining >= outstanding ? outstanding : remaining;
        transaction.update(entry.key, {'paidAmount': FieldValue.increment(applied)});
        allocations.add({'orderId': entry.key.id, 'amount': applied});
        remaining -= applied;
      }

      if (remaining > 0.0001) {
        throw Exception('تعذر توزيع مبلغ السداد بالكامل على الفواتير الحالية. حدّث الصفحة وحاول مرة أخرى.');
      }

      transaction.update(customerRef, {
        'totalDebt': FieldValue.increment(-amountPaid),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (activeShiftRef != null) {
        if (paymentMethod == 'cash') {
          transaction.update(activeShiftRef, {'debtCollectionsCash': FieldValue.increment(amountPaid)});
        } else if (paymentMethod == 'card' || paymentMethod == 'mada') {
          transaction.update(activeShiftRef, {'debtCollectionsCard': FieldValue.increment(amountPaid)});
        } else if (paymentMethod == 'transfer') {
          transaction.update(activeShiftRef, {'debtCollectionsTransfer': FieldValue.increment(amountPaid)});
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
      if (order.status != 'cancelled' && order.customerId != 'walk_in' && order.customerId.isNotEmpty) {
        final customerRef = firestore.collection('customers').doc(order.customerId);
        final debtDecrease = order.isCredit ? (order.total - order.paidAmount) : 0.0;
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
        await OrderBranchInventoryService(firestore).reDeductAfterCancellationReversal(order);
      }
      rethrow;
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../branches/data/order_branch_inventory_service.dart';
import '../domain/order.dart';
import 'order_repository.dart';

/// Multi-branch adapter around the proven v1.0.107 order repository.
///
/// Main Branch deliberately delegates to the untouched v107 implementation so
/// existing merchants keep the exact accounting/inventory behaviour they use
/// today. Non-main branches use isolated branch inventory documents.
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
      final serverNumber = await firestore.runTransaction<int>((tx) async {
        final snap = await tx.get(counterRef);
        final data = snap.data();
        final current = data?['date'] == date ? (data?['lastNumber'] as num?)?.toInt() ?? 0 : 0;
        final next = (current > localNumber ? current : localNumber) + 1;
        tx.set(counterRef, {
          'date': date,
          'lastNumber': next,
          'branchId': branchId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return next;
      });
      localNumber = serverNumber;
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
    final scopedOrder = order.copyWith(branchId: branchId);

    // Golden compatibility path: v107 remains authoritative for Main Branch.
    if (branchId == 'main') {
      return super.createOrder(scopedOrder, shiftId: shiftId);
    }

    final queueNumber = await _nextBranchQueueNumber(order.merchantId, branchId);
    final orderWithQueue = scopedOrder.copyWith(queueNumber: queueNumber);

    // Inventory first uses an atomic multi-item transaction and fails the sale
    // before any financial records are written if branch stock is insufficient.
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
      double orderTax = 0.0;
      for (final item in orderWithQueue.items) {
        final tax = item.taxPercentage ?? 0.0;
        if (tax <= 0) continue;
        final inclusive = item.isTaxInclusive ?? true;
        orderTax += inclusive
            ? item.total - (item.total / (1 + tax / 100))
            : item.total * (tax / 100);
      }

      final updates = <String, dynamic>{
        if (orderTax > 0) 'totalTax': FieldValue.increment(orderTax),
      };
      switch (orderWithQueue.paymentMethod) {
        case 'cash':
          updates['cashSales'] = FieldValue.increment(orderWithQueue.paidAmount);
          break;
        case 'card':
        case 'mada':
        case 'apple_pay':
          updates['cardTotal'] = FieldValue.increment(orderWithQueue.paidAmount);
          break;
        case 'transfer':
          updates['transferTotal'] = FieldValue.increment(orderWithQueue.paidAmount);
          break;
        case 'split':
          if ((orderWithQueue.splitCashAmount ?? 0) > 0) {
            updates['cashSales'] = FieldValue.increment(orderWithQueue.splitCashAmount!);
          }
          if ((orderWithQueue.splitNetworkAmount ?? 0) > 0) {
            updates['cardTotal'] = FieldValue.increment(orderWithQueue.splitNetworkAmount!);
          }
          break;
      }
      if (updates.isNotEmpty) batch.update(shiftRef, updates);
    }

    batch.set(orderRef, orderWithQueue.toJson());
    try {
      await batch.commit();
      return orderWithQueue;
    } catch (e) {
      // Compensating rollback. This path is intentionally explicit because
      // inventory and accounting use different Firestore transaction scopes.
      await OrderBranchInventoryService(firestore)
          .restoreForDeletion(orderWithQueue);
      rethrow;
    }
  }

  @override
  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {
    if (order.branchId == 'main') {
      return super.updateOrderStatus(order, newStatus);
    }
    if (order.status == newStatus) return;

    if (newStatus == 'cancelled' && order.status != 'cancelled') {
      await OrderBranchInventoryService(firestore).restoreForCancellation(order);
    } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
      await OrderBranchInventoryService(firestore)
          .reDeductAfterCancellationReversal(order);
    }

    try {
      await _applyStatusFinancials(order, newStatus);
    } catch (e) {
      // Restore inventory to the pre-transition state when financial/status
      // mutation fails, so a branch can never retain a half-cancelled order.
      if (newStatus == 'cancelled' && order.status != 'cancelled') {
        await OrderBranchInventoryService(firestore)
            .reDeductAfterCancellationReversal(order);
      } else if (order.status == 'cancelled' && newStatus != 'cancelled') {
        await OrderBranchInventoryService(firestore).restoreForCancellation(order);
      }
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
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _appendRefundToOpenBranchShift(
    WriteBatch batch,
    AppOrder order,
  ) async {
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
    double orderTax = 0.0;
    for (final item in order.items) {
      final tax = item.taxPercentage ?? 0.0;
      if (tax <= 0) continue;
      final inclusive = item.isTaxInclusive ?? true;
      orderTax += inclusive
          ? item.total - (item.total / (1 + tax / 100))
          : item.total * (tax / 100);
    }
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
  Future<void> deleteOrder(AppOrder order) async {
    if (order.branchId == 'main') return super.deleteOrder(order);

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
    } catch (e) {
      if (order.status != 'cancelled') {
        await OrderBranchInventoryService(firestore)
            .reDeductAfterCancellationReversal(order);
      }
      rethrow;
    }
  }
}

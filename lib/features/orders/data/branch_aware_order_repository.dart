import '../../../core/services/entitlement_integration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../branches/data/order_branch_inventory_service.dart';
import '../domain/order.dart';
import '../domain/order_return.dart';
import 'order_repository.dart';

/// Multi-branch implementation that preserves the v1.0.107 accounting formulas
/// while changing only the inventory/shift scope from merchant-wide to branch.
class BranchAwareOrderRepository extends OrderRepository {
  final OrderBranchInventoryService inventoryService;
  final FirebaseFirestore firestore;

  @visibleForTesting
  final String? testUid;

  BranchAwareOrderRepository(this.firestore, {this.testUid})
    : inventoryService = OrderBranchInventoryService(firestore),
      super(firestore);

  String _operationBranch(String branchId) =>
      branchId.trim().isEmpty ? 'main' : branchId.trim();

  @override
  Future<AppOrder> createOrder(
    AppOrder order, {
    String? shiftId,
    String? branchId,
  }) async {

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('createOrder');
      final operationId = const Uuid().v4();
      final effectiveBranchId = _operationBranch(branchId ?? order.branchId);
      final result = await callable.call({
        'operationId': operationId,
        'order': order.toJson(),
        'shiftId': shiftId,
        'branchId': effectiveBranchId,
      });
      // Optionally re-fetch the order from Firestore if needed, but for now just return the local copy with the id
      return order;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }

}

  Future<bool> _canReadCosts() async {
    String? uid = testUid;
    if (uid == null) {
      try {
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        return false;
      }
    }
    if (uid == null) return false;
    try {
      final userDoc = await firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      if (data == null) return false;
      if (data['role'] == 'merchant') return true;
      if (data['role'] == 'employee') {
        final perms = data['permissions'] as Map<String, dynamic>?;
        return perms?['can_view_cost'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<AppOrder> _attachHistoricalCosts(
    Transaction tx,
    AppOrder order, {
    required bool canReadCosts,
  }) async {
    final productIds = order.items
        .map((item) => item.productId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (productIds.isEmpty) return order;

    final products = <String, Map<String, dynamic>>{};
    final rawMaterialIds = <String>{};
    for (final productId in productIds) {
      var snap = await tx.get(
        firestore
            .collection('merchants')
            .doc(order.merchantId)
            .collection('branches')
            .doc(order.branchId)
            .collection('products')
            .doc(productId),
      );
      if (!snap.exists) {
        final allowed = await _legacyItemAllowedInBranch(
          tx,
          merchantId: order.merchantId,
          branchId: order.branchId,
          itemType: 'product',
          itemId: productId,
        );
        if (allowed) {
          snap = await tx.get(firestore.collection('products').doc(productId));
        }
      }
      if (!snap.exists || snap.data() == null) continue;
      final data = snap.data()!;
      products[productId] = data;
      for (final raw in (data['recipe'] as List<dynamic>? ?? const [])) {
        final map = Map<String, dynamic>.from(raw as Map);
        final rawId = map['rawMaterialId']?.toString();
        if (rawId != null && rawId.isNotEmpty) rawMaterialIds.add(rawId);
      }
    }

    final costs = <String, double>{};
    if (canReadCosts) {
      final costIds = {...productIds, ...rawMaterialIds};
      for (final id in costIds) {
        final snap = await tx.get(
          firestore
              .collection('merchants')
              .doc(order.merchantId)
              .collection('product_costs')
              .doc('${order.branchId}_$id'),
        );
        final value = snap.data()?['costPrice'];
        if (value is num && value >= 0) costs[id] = value.toDouble();
        if (value is! num) {
          final legacySnap = await tx.get(
            firestore
                .collection('merchants')
                .doc(order.merchantId)
                .collection('product_costs')
                .doc(id),
          );
          final legacyValue = legacySnap.data()?['costPrice'];
          if (legacyValue is num && legacyValue >= 0) {
            costs[id] = legacyValue.toDouble();
          }
        }
      }
    }

    final items = order.items.map((item) {
      final product = products[item.productId];
      final isManufacturedOnDemand =
          item.isManufacturedOnDemand ||
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

  Future<bool> _legacyItemAllowedInBranch(
    Transaction tx, {
    required String merchantId,
    required String branchId,
    required String itemType,
    required String itemId,
  }) async {
    if (branchId == 'main') return true;
    final availabilityCollection = itemType == 'product'
        ? 'product_branch_availability'
        : 'raw_material_branch_availability';
    final availabilityItemField = itemType == 'product'
        ? 'productId'
        : 'rawMaterialId';
    final availabilityId = '${branchId}_$itemId';
    final availabilitySnap = await tx.get(
      firestore
          .collection('merchants')
          .doc(merchantId)
          .collection(availabilityCollection)
          .doc(availabilityId),
    );
    if (availabilitySnap.exists &&
        availabilitySnap.data()?['enabled'] == true &&
        availabilitySnap.data()?[availabilityItemField]?.toString() == itemId) {
      return true;
    }
    final inventoryId = '${branchId}_${itemType}_$itemId';
    final inventorySnap = await tx.get(
      firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branch_inventory')
          .doc(inventoryId),
    );
    return inventorySnap.exists;
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
          updates['cardTotal'] = FieldValue.increment(
            order.splitNetworkAmount!,
          );
        }
        break;
    }
    return updates;
  }

  double _orderTax(AppOrder order) {
    double orderTax = 0.0;
    for (final item in order.items) {
      final tax = item.getEffectiveTax(0.0);
      if (tax <= 0) continue;
      final inclusive = item.isTaxInclusive ?? true;
      final taxableBase = item.total - (item.discountAmount ?? 0.0);
      orderTax += inclusive
          ? taxableBase - (taxableBase / (1 + tax / 100))
          : taxableBase * (tax / 100);
    }
    return orderTax;
  }

  @override
  Future<void> updateOrderStatus(AppOrder order, String newStatus) async {

    try {
      if (newStatus == 'cancelled') {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('cancelOrder');
        final operationId = const Uuid().v4();
        await callable.call({
          'operationId': operationId,
          'orderId': order.id,
          'shiftId': order.shiftId,
        });
      } else {
        // Normal non-financial status transition
        final orderRef = firestore.collection('orders').doc(order.id);
        await orderRef.update({
          'status': newStatus,
          'statusTransition': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }

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
          updates['refundsCard'] = FieldValue.increment(
            order.splitNetworkAmount!,
          );
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
    String branchId = 'main',
  }) async {

    try {
      if (amountPaid <= 0) return;
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('payCustomerDebt');
      final operationId = const Uuid().v4();
      final paymentId = const Uuid().v4();
      
      await callable.call({
        'operationId': operationId,
        'paymentId': paymentId,
        'customerId': customerId,
        'amount': amountPaid,
        'paymentMethod': paymentMethod,
        'shiftId': shiftId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to pay debt: $e');
    }

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
        final customerRef = firestore
            .collection('customers')
            .doc(order.customerId);
        final debtDecrease = order.isCredit
            ? (order.total - order.paidAmount)
            : 0.0;
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
        await OrderBranchInventoryService(
          firestore,
        ).reDeductAfterCancellationReversal(order);
      }
      rethrow;
    }
  }

  @override
  Future<AppOrder> returnOrderItems(
    AppOrder originalOrder,
    OrderReturn orderReturn,
  ) async {

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('partialReturn');
      final operationId = const Uuid().v4();
      final returnedItemsData = orderReturn.returnedItems.map((e) => {
        'lineId': e.lineId,
        'quantity': e.quantity,
        'reason': e.reason,
      }).toList();
      
      await callable.call({
        'operationId': operationId,
        'orderId': originalOrder.id,
        'returnId': orderReturn.id,
        'returnedItems': returnedItemsData,
        'shiftId': originalOrder.shiftId,
      });
      
      // We should ideally fetch the updated order, but returning the original is a placeholder 
      // since the UI will likely refresh from a stream.
      return originalOrder;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to process return: $e');
    }

}
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../orders/domain/order.dart';
import 'branch_inventory_repository.dart';

class OrderBranchInventoryService {
  final FirebaseFirestore firestore;

  OrderBranchInventoryService(this.firestore);

  Future<void> applySale(AppOrder order, {required int queueNumber}) {
    return _apply(order, sign: -1, reasonPrefix: 'فاتورة مبيعات #$queueNumber');
  }

  Future<void> restoreForCancellation(AppOrder order) {
    return _apply(order, sign: 1, reasonPrefix: 'استرجاع مخزون بسبب إلغاء فاتورة #${order.queueNumber ?? order.id}');
  }

  Future<void> restoreForDeletion(AppOrder order) {
    return _apply(order, sign: 1, reasonPrefix: 'استرجاع مخزون بسبب حذف نهائي لفاتورة #${order.queueNumber ?? order.id}');
  }

  Future<void> reDeductAfterCancellationReversal(AppOrder order) {
    return _apply(order, sign: -1, reasonPrefix: 'خصم مخزون بسبب التراجع عن إلغاء الفاتورة #${order.queueNumber ?? order.id}');
  }

  Future<void> _apply(AppOrder order, {required int sign, required String reasonPrefix}) async {
    if (sign != 1 && sign != -1) throw ArgumentError.value(sign, 'sign');

    final productIds = order.items.map((item) => item.productId).where((id) => id.isNotEmpty).toSet().toList();
    final productSnaps = await Future.wait(productIds.map((id) => firestore.collection('products').doc(id).get(const GetOptions(source: Source.serverAndCache))));
    final products = <String, Map<String, dynamic>>{};
    final rawMaterialIds = <String>{};
    for (final snap in productSnaps) {
      if (!snap.exists || snap.data() == null) continue;
      final data = snap.data()!;
      products[snap.id] = data;
      for (final raw in (data['recipe'] as List<dynamic>? ?? const [])) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['rawMaterialId']?.toString();
        if (id != null && id.isNotEmpty) rawMaterialIds.add(id);
      }
    }

    final rawSnaps = await Future.wait(rawMaterialIds.map((id) => firestore.collection('raw_materials').doc(id).get(const GetOptions(source: Source.serverAndCache))));
    final rawMaterials = <String, Map<String, dynamic>>{
      for (final snap in rawSnaps)
        if (snap.exists && snap.data() != null) snap.id: snap.data()!,
    };

    final mutations = <BranchInventoryMutation>[];
    final productNames = <String, String>{};
    final rawNames = <String, String>{};
    final rawParentNames = <String, String>{};
    final productDeltas = <String, double>{};
    final rawDeltas = <String, double>{};

    for (final item in order.items) {
      final data = products[item.productId];
      if (data == null) continue;
      final productName = data['name']?.toString() ?? item.productName;
      if (!(data['isManufacturedOnDemand'] as bool? ?? false)) {
        productDeltas[item.productId] = (productDeltas[item.productId] ?? 0) + sign * item.quantity;
        productNames[item.productId] = productName;
      }
      for (final raw in (data['recipe'] as List<dynamic>? ?? const [])) {
        final map = Map<String, dynamic>.from(raw as Map);
        final rawId = map['rawMaterialId']?.toString() ?? '';
        if (rawId.isEmpty) continue;
        final amount = (map['amountRequired'] as num?)?.toDouble() ?? 0.0;
        rawDeltas[rawId] = (rawDeltas[rawId] ?? 0) + sign * amount * item.quantity;
        rawNames[rawId] = rawMaterials[rawId]?['name']?.toString() ?? 'مادة خام';
        rawParentNames[rawId] = productName;
      }
    }

    for (final entry in productDeltas.entries) {
      mutations.add(BranchInventoryMutation(
        itemType: 'product',
        itemId: entry.key,
        delta: entry.value,
        legacyMainQuantity: (products[entry.key]?['quantity'] as num?)?.toDouble() ?? 0.0,
      ));
    }
    for (final entry in rawDeltas.entries) {
      mutations.add(BranchInventoryMutation(
        itemType: 'raw_material',
        itemId: entry.key,
        delta: entry.value,
        legacyMainQuantity: (rawMaterials[entry.key]?['quantity'] as num?)?.toDouble() ?? 0.0,
      ));
    }

    final repository = BranchInventoryRepository(firestore, order.merchantId);
    final previous = <String, double>{};
    for (final mutation in mutations) {
      final current = await repository.getItem(branchId: order.branchId, itemType: mutation.itemType, itemId: mutation.itemId);
      previous[repository.docId(order.branchId, mutation.itemType, mutation.itemId)] = current?.quantity ?? (order.branchId == 'main' ? mutation.legacyMainQuantity : 0.0);
    }

    final next = await repository.changeQuantities(branchId: order.branchId, mutations: mutations);
    final batch = firestore.batch();
    for (final mutation in mutations) {
      final key = repository.docId(order.branchId, mutation.itemType, mutation.itemId);
      final logRef = firestore.collection('merchants').doc(order.merchantId).collection('inventory_logs').doc();
      final isRaw = mutation.itemType == 'raw_material';
      batch.set(logRef, {
        'id': logRef.id,
        'merchantId': order.merchantId,
        'branchId': order.branchId,
        'productId': mutation.itemId,
        'productName': isRaw ? (rawNames[mutation.itemId] ?? 'مادة خام') : (productNames[mutation.itemId] ?? 'منتج'),
        'changeQuantity': mutation.delta,
        'previousQuantity': previous[key] ?? 0.0,
        'newQuantity': next[key] ?? 0.0,
        'reason': isRaw ? '$reasonPrefix — ${rawParentNames[mutation.itemId] ?? ''}' : reasonPrefix,
        'date': FieldValue.serverTimestamp(),
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      // Inventory and its audit trail must behave as one logical operation.
      // If the log write fails, reverse the exact inventory mutation before
      // surfacing the failure to the caller.
      final rollback = mutations
          .map((mutation) => BranchInventoryMutation(
                itemType: mutation.itemType,
                itemId: mutation.itemId,
                delta: -mutation.delta,
                legacyMainQuantity: mutation.legacyMainQuantity,
              ))
          .toList();
      await repository.changeQuantities(branchId: order.branchId, mutations: rollback);
      rethrow;
    }
  }
}

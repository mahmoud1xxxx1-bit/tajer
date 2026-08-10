import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../authentication/data/auth_repository.dart';
import '../../orders/domain/cart_item.dart';
import '../../orders/domain/order.dart';
import 'branch_inventory_repository.dart';

class OrderBranchInventoryService {
  final FirebaseFirestore firestore;

  OrderBranchInventoryService(this.firestore);

  Future<void> applySale(AppOrder order, {required int queueNumber}) {
    return _apply(
      order,
      sign: -1,
      reasonPrefix: 'Sales invoice #$queueNumber',
    );
  }

  Future<void> applySaleInTransaction(
    Transaction tx,
    AppOrder order, {
    required int queueNumber,
  }) {
    return _applyInTransaction(
      tx,
      order,
      sign: -1,
      reasonPrefix: 'Sales invoice #$queueNumber',
    );
  }

  Future<void> restoreForCancellation(AppOrder order) {
    return _apply(
      order,
      sign: 1,
      reasonPrefix:
          'Inventory restored for cancelled invoice #${order.queueNumber ?? order.id}',
    );
  }

  Future<void> restoreForCancellationInTransaction(
    Transaction tx,
    AppOrder order,
  ) {
    return _applyInTransaction(
      tx,
      order,
      sign: 1,
      reasonPrefix:
          'Inventory restored for cancelled invoice #${order.queueNumber ?? order.id}',
    );
  }

  Future<void> restoreForPartialReturnInTransaction(
    Transaction tx,
    AppOrder order,
    List<CartItem> returnedItems,
  ) async {
    final productDeltas = <String, double>{};
    final rawDeltas = <String, double>{};
    final productNames = <String, String>{};
    final rawParentNames = <String, String>{};

    for (final returnedItem in returnedItems) {
      final lineId = returnedItem.lineId;
      final originalLine = lineId != null 
          ? order.items.cast<CartItem?>().firstWhere((i) => i?.lineId == lineId, orElse: () => null)
          : null;

      final isMto = originalLine?.isManufacturedOnDemand ?? returnedItem.isManufacturedOnDemand;
      final recipe = originalLine?.historicalMtoRecipe ?? returnedItem.historicalMtoRecipe;
      final productName = originalLine?.productName ?? returnedItem.productName;
      final productId = originalLine?.productId ?? returnedItem.productId;

      if (isMto) {
        if (recipe == null) {
          throw Exception('Cannot partially return legacy MTO item without historical recipe snapshot.');
        }
        for (final raw in recipe) {
          final rawId = raw['rawMaterialId']?.toString() ?? '';
          final perUnit = (raw['amountRequired'] as num?)?.toDouble() ?? 0.0;
          if (rawId.isEmpty || perUnit <= 0) continue;
          
          rawDeltas[rawId] = (rawDeltas[rawId] ?? 0) + (perUnit * returnedItem.quantity);
          rawParentNames[rawId] = productName;
        }
      } else {
        productDeltas[productId] = (productDeltas[productId] ?? 0) + returnedItem.quantity;
        productNames[productId] = productName;
      }
    }

    await _applyMutationsInTransaction(
      tx: tx,
      order: order,
      productDeltas: productDeltas,
      rawDeltas: rawDeltas,
      products: const {},
      rawMaterials: const {},
      productNames: productNames,
      rawNames: const {}, // Will fallback to 'Raw material'
      rawParentNames: rawParentNames,
      reasonPrefix: 'Inventory restored for partial return of invoice #${order.queueNumber ?? order.id}',
    );
  }

  Future<void> restoreForDeletion(AppOrder order) {
    return _apply(
      order,
      sign: 1,
      reasonPrefix:
          'Inventory restored for deleted invoice #${order.queueNumber ?? order.id}',
    );
  }

  Future<void> reDeductAfterCancellationReversal(AppOrder order) {
    return _apply(
      order,
      sign: -1,
      reasonPrefix:
          'Inventory deducted after cancellation reversal #${order.queueNumber ?? order.id}',
    );
  }

  Future<void> reDeductAfterCancellationReversalInTransaction(
    Transaction tx,
    AppOrder order,
  ) {
    return _applyInTransaction(
      tx,
      order,
      sign: -1,
      reasonPrefix:
          'Inventory deducted after cancellation reversal #${order.queueNumber ?? order.id}',
    );
  }

  Future<void> _apply(
    AppOrder order, {
    required int sign,
    required String reasonPrefix,
  }) {
    return firestore.runTransaction<void>((tx) {
      return _applyInTransaction(
        tx,
        order,
        sign: sign,
        reasonPrefix: reasonPrefix,
      );
    });
  }

  Future<void> _applyInTransaction(
    Transaction tx,
    AppOrder order, {
    required int sign,
    required String reasonPrefix,
  }) async {
    if (sign != 1 && sign != -1) {
      throw ArgumentError.value(sign, 'sign');
    }

    final productIds = order.items
        .map((item) => item.productId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final productSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in productIds) {
      var snap = await tx.get(firestore
          .collection('merchants')
          .doc(order.merchantId)
          .collection('branches')
          .doc(order.branchId)
          .collection('products')
          .doc(id));
      if (!snap.exists) {
        final allowed = await _legacyItemAllowedInBranch(
          tx,
          merchantId: order.merchantId,
          branchId: order.branchId,
          itemType: 'product',
          itemId: id,
        );
        if (allowed) {
          snap = await tx.get(firestore.collection('products').doc(id));
        }
      }
      productSnaps.add(snap);
    }

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

    final rawSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in rawMaterialIds) {
      var snap = await tx.get(firestore
          .collection('merchants')
          .doc(order.merchantId)
          .collection('branches')
          .doc(order.branchId)
          .collection('raw_materials')
          .doc(id));
      if (!snap.exists) {
        final allowed = await _legacyItemAllowedInBranch(
          tx,
          merchantId: order.merchantId,
          branchId: order.branchId,
          itemType: 'raw_material',
          itemId: id,
        );
        if (allowed) {
          snap = await tx.get(firestore.collection('raw_materials').doc(id));
        }
      }
      rawSnaps.add(snap);
    }

    final rawMaterials = <String, Map<String, dynamic>>{
      for (final snap in rawSnaps)
        if (snap.exists && snap.data() != null) snap.id: snap.data()!,
    };

    final productNames = <String, String>{};
    final rawNames = <String, String>{};
    final rawParentNames = <String, String>{};
    final productDeltas = <String, double>{};
    final rawDeltas = <String, double>{};

    for (final item in order.items) {
      final data = products[item.productId];
      if (data == null) {
        if (sign < 0) {
          throw Exception(
              'Product is not available in this branch: ${item.productId}');
        }
        continue;
      }

      final productName = data['name']?.toString() ?? item.productName;
      final isManufacturedOnDemand = item.isManufacturedOnDemand ||
          (data['isManufacturedOnDemand'] as bool? ?? false);
      if (!isManufacturedOnDemand) {
        productDeltas[item.productId] =
            (productDeltas[item.productId] ?? 0) + sign * item.quantity;
        productNames[item.productId] = productName;
      }

      for (final raw in (data['recipe'] as List<dynamic>? ?? const [])) {
        final map = Map<String, dynamic>.from(raw as Map);
        final rawId = map['rawMaterialId']?.toString() ?? '';
        if (rawId.isEmpty) continue;

        final amount = (map['amountRequired'] as num?)?.toDouble() ?? 0.0;
        rawDeltas[rawId] =
            (rawDeltas[rawId] ?? 0) + sign * amount * item.quantity;
        rawNames[rawId] =
            rawMaterials[rawId]?['name']?.toString() ?? 'Raw material';
        rawParentNames[rawId] = productName;
      }
    }

    await _applyMutationsInTransaction(
      tx: tx,
      order: order,
      productDeltas: productDeltas,
      rawDeltas: rawDeltas,
      products: products,
      rawMaterials: rawMaterials,
      productNames: productNames,
      rawNames: rawNames,
      rawParentNames: rawParentNames,
      reasonPrefix: reasonPrefix,
    );
  }

  Future<void> _applyMutationsInTransaction({
    required Transaction tx,
    required AppOrder order,
    required Map<String, double> productDeltas,
    required Map<String, double> rawDeltas,
    required Map<String, Map<String, dynamic>> products,
    required Map<String, Map<String, dynamic>> rawMaterials,
    required Map<String, String> productNames,
    required Map<String, String> rawNames,
    required Map<String, String> rawParentNames,
    required String reasonPrefix,
  }) async {

    final mutations = <BranchInventoryMutation>[];
    for (final entry in productDeltas.entries) {
      mutations.add(
        BranchInventoryMutation(
          itemType: 'product',
          itemId: entry.key,
          delta: entry.value,
          legacyMainQuantity:
              (products[entry.key]?['quantity'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }
    for (final entry in rawDeltas.entries) {
      mutations.add(
        BranchInventoryMutation(
          itemType: 'raw_material',
          itemId: entry.key,
          delta: entry.value,
          legacyMainQuantity:
              (rawMaterials[entry.key]?['quantity'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    if (mutations.isEmpty) return;

    final repository = BranchInventoryRepository(firestore, order.merchantId);
    final inventoryRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    final logRefs = <String, DocumentReference<Map<String, dynamic>>>{};

    for (final mutation in mutations) {
      final key = repository.docId(
        order.branchId,
        mutation.itemType,
        mutation.itemId,
      );
      inventoryRefs[key] = repository.ref.doc(key);
      logRefs[key] = firestore
          .collection('merchants')
          .doc(order.merchantId)
          .collection('inventory_logs')
          .doc();
    }

    final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final entry in inventoryRefs.entries) {
      snapshots[entry.key] = await tx.get(entry.value);
    }

    final previous = <String, double>{};
    final next = <String, double>{};

    for (final mutation in mutations) {
      final key = repository.docId(
        order.branchId,
        mutation.itemType,
        mutation.itemId,
      );
      final snap = snapshots[key]!;
      final current = snap.exists
          ? (snap.data()?['quantity'] as num?)?.toDouble() ?? 0.0
          : (order.branchId == 'main' ? mutation.legacyMainQuantity : 0.0);
      final calculated = current + mutation.delta;

      if (calculated < -0.000001) {
        if (mutation.itemType == 'raw_material') {
          throw Exception(
            'Insufficient raw material inventory: ${mutation.itemId}',
          );
        }
        throw Exception(
          'Insufficient branch inventory: ${mutation.itemId}',
        );
      }

      previous[key] = current;
      next[key] = calculated < 0 ? 0.0 : calculated;
    }

    final userEmail = _currentUserEmail();

    // Fetch branch name for notifications (F1 compliance)
    String branchNameForNotif = 'فرع غير معروف';
    if (order.branchId == 'main') {
      branchNameForNotif = 'الرئيسي';
    } else {
      final branchSnap = await tx.get(firestore
          .collection('merchants')
          .doc(order.merchantId)
          .collection('branches')
          .doc(order.branchId));
      if (branchSnap.exists) {
        branchNameForNotif = branchSnap.data()?['name']?.toString() ?? 'فرع غير معروف';
      }
    }

    for (final mutation in mutations) {
      final key = repository.docId(
        order.branchId,
        mutation.itemType,
        mutation.itemId,
      );
      final snap = snapshots[key]!;
      final isRaw = mutation.itemType == 'raw_material';

      // Low Stock Notification Deduplication Logic (F4)
      if (!isRaw && mutation.delta < 0) {
        final productData = products[mutation.itemId];
        if (productData != null) {
          final threshold = (productData['lowStockThreshold'] as num?)?.toDouble() ?? 0.0;
          final previousQty = previous[key] ?? 0.0;
          final newQty = next[key] ?? 0.0;
          if (threshold > 0 && previousQty > threshold && newQty <= threshold) {
            final notifRef = firestore
                .collection('users')
                .doc(order.merchantId)
                .collection('notifications')
                .doc();
            tx.set(notifRef, {
              'title': 'تنبيه انخفاض المخزون | Low Stock Alert',
              'message':
                  'انخفض مخزون المنتج ${productNames[mutation.itemId]} إلى ما دون الحد الأدنى في $branchNameForNotif.',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
      }

      tx.set(
        inventoryRefs[key]!,
        {
          'id': key,
          'merchantId': order.merchantId,
          'branchId': order.branchId,
          'itemId': mutation.itemId,
          'itemType': mutation.itemType,
          'quantity': next[key],
          'initialQuantity': snap.exists
              ? ((snap.data()?['initialQuantity'] as num?)?.toDouble() ??
                  previous[key])
              : previous[key],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final logRef = logRefs[key]!;
      tx.set(logRef, {
        'id': logRef.id,
        'merchantId': order.merchantId,
        'branchId': order.branchId,
        'productId': mutation.itemId,
        'productName': isRaw
            ? (rawNames[mutation.itemId] ?? 'Raw material')
            : (productNames[mutation.itemId] ?? 'Product'),
        'changeQuantity': mutation.delta,
        'previousQuantity': previous[key] ?? 0.0,
        'newQuantity': next[key] ?? 0.0,
        'reason': isRaw
            ? '$reasonPrefix - ${rawParentNames[mutation.itemId] ?? ''}'
            : reasonPrefix,
        'date': FieldValue.serverTimestamp(),
        'userEmail': userEmail,
      });
    }
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
    final availabilityItemField =
        itemType == 'product' ? 'productId' : 'rawMaterialId';
    final availabilityId = '${branchId}_$itemId';
    final availabilitySnap = await tx.get(firestore
        .collection('merchants')
        .doc(merchantId)
        .collection(availabilityCollection)
        .doc(availabilityId));
    if (availabilitySnap.exists &&
        availabilitySnap.data()?['enabled'] == true &&
        availabilitySnap.data()?[availabilityItemField]?.toString() == itemId) {
      return true;
    }
    final inventoryId = '${branchId}_${itemType}_$itemId';
    final inventorySnap = await tx.get(firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc(inventoryId));
    return inventorySnap.exists;
  }

  String _currentUserEmail() {
    try {
      return FirebaseAuth.instance.currentUser?.email ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }
}

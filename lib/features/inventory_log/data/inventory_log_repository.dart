import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/inventory_log.dart';

class InventoryLogRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  InventoryLogRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('inventory_logs');

  Query<InventoryLog> queryLogs() {
    return _logsRef
        .withConverter<InventoryLog>(
          fromFirestore: (snapshot, _) {
            final data = Map<String, dynamic>.from(snapshot.data() ?? {});
            data['id'] = snapshot.id;
            data['productId'] = data['productId']?.toString() ?? '';
            data['productName'] = data['productName']?.toString() ?? '';
            data['reason'] = data['reason']?.toString() ?? '';
            data['merchantId'] = data['merchantId']?.toString() ?? '';
            data['changeQuantity'] = double.tryParse(data['changeQuantity']?.toString() ?? '0') ?? 0.0;
            data['previousQuantity'] = double.tryParse(data['previousQuantity']?.toString() ?? '0') ?? 0.0;
            data['newQuantity'] = double.tryParse(data['newQuantity']?.toString() ?? '0') ?? 0.0;
            if (data['date'] == null) data['date'] = Timestamp.now();
            return InventoryLog.fromJson(data);
          },
          toFirestore: (log, _) => log.toJson(),
        )
        .orderBy('date', descending: true)
        // Note: FirestoreListView cannot easily filter out specific document IDs (like 'store_profile_doc') natively without breaking limit.
        .where('date', isLessThanOrEqualTo: Timestamp.now());
  }

  Stream<List<InventoryLog>> watchLogs() {
    return _logsRef.withConverter<InventoryLog?>(
      fromFirestore: (snapshot, _) {
        try {
          final data = Map<String, dynamic>.from(snapshot.data() ?? {});
          data['id'] = snapshot.id;
          data['productId'] = data['productId']?.toString() ?? '';
          data['productName'] = data['productName']?.toString() ?? '';
          data['reason'] = data['reason']?.toString() ?? '';
          data['merchantId'] = data['merchantId']?.toString() ?? '';
          data['changeQuantity'] = double.tryParse(data['changeQuantity']?.toString() ?? '0') ?? 0.0;
          data['previousQuantity'] = double.tryParse(data['previousQuantity']?.toString() ?? '0') ?? 0.0;
          data['newQuantity'] = double.tryParse(data['newQuantity']?.toString() ?? '0') ?? 0.0;
          if (data['date'] == null) data['date'] = Timestamp.now();
          return InventoryLog.fromJson(data);
        } catch (e) {
          debugPrint('Error parsing InventoryLog ${snapshot.id}: $e');
          return null;
        }
      },
      toFirestore: (log, _) => log?.toJson() ?? {},
    ).orderBy('date', descending: true).limit(1000).snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id != 'store_profile_doc' && !doc.id.startsWith('counter_') && !doc.id.startsWith('act_'))
          .map((doc) => doc.data())
          .where((log) => log != null)
          .cast<InventoryLog>()
          .toList();
    });
  }

  Future<void> logChange({
    required String productId,
    required String productName,
    required num previousQuantity,
    required num newQuantity,
    required String reason,
    String? userEmail,
    String? userName,
    String? itemType,
  }) async {
    final change = (newQuantity - previousQuantity).toDouble();
    if (change == 0) return; // No real change

    final log = InventoryLog(
      id: Uuid().v4(),
      merchantId: _merchantId,
      productId: productId,
      productName: productName,
      changeQuantity: change,
      previousQuantity: previousQuantity.toDouble(),
      newQuantity: newQuantity.toDouble(),
      reason: reason,
      userEmail: userEmail,
      userName: userName,
      itemType: itemType,
      date: DateTime.now(),
    );

    await _logsRef.doc(log.id).set(log.toJson());
  }

  Future<void> revertLog(
    InventoryLog log, {
    required String userEmail,
    required String userName,
  }) async {
    if (log.isReverted) return;

    final sourceLogRef = _logsRef.doc(log.id);
    final revertLogId = Uuid().v4();
    final revertLogRef = _logsRef.doc(revertLogId);
    final revertDate = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      // Re-read the source inside the transaction. This makes a repeated tap or
      // a Firestore transaction retry idempotent.
      final sourceSnapshot = await transaction.get(sourceLogRef);
      if (!sourceSnapshot.exists) {
        throw Exception('تعذر العثور على حركة المخزون الأصلية.');
      }

      final sourceData = sourceSnapshot.data() ?? const <String, dynamic>{};
      if (sourceData['isReverted'] == true) return;

      final productId = sourceData['productId']?.toString() ?? log.productId;
      final productName =
          sourceData['productName']?.toString() ?? log.productName;
      final itemType = sourceData['itemType']?.toString() ?? log.itemType;
      final changeQuantity = double.tryParse(
            sourceData['changeQuantity']?.toString() ??
                log.changeQuantity.toString(),
          ) ??
          log.changeQuantity;

      DocumentReference<Map<String, dynamic>>? inventoryRef;
      double currentInventory = 0.0;

      // Every read is completed before any write, as required by Firestore
      // transactions.
      if (productId.isNotEmpty && changeQuantity != 0) {
        final productRef = _firestore.collection('products').doc(productId);
        final productSnapshot = await transaction.get(productRef);

        if (productSnapshot.exists) {
          inventoryRef = productRef;
          currentInventory = double.tryParse(
                productSnapshot.data()?['quantity']?.toString() ?? '0',
              ) ??
              0.0;
        } else {
          final rawMaterialRef =
              _firestore.collection('raw_materials').doc(productId);
          final rawMaterialSnapshot = await transaction.get(rawMaterialRef);
          if (!rawMaterialSnapshot.exists) {
            throw Exception('تعذر العثور على المنتج أو المادة الخام المرتبطة بالحركة.');
          }
          inventoryRef = rawMaterialRef;
          currentInventory = double.tryParse(
                rawMaterialSnapshot.data()?['quantity']?.toString() ?? '0',
              ) ??
              0.0;
        }
      }

      final reversingLog = InventoryLog(
        id: revertLogId,
        merchantId: _merchantId,
        productId: productId,
        productName: productName,
        changeQuantity: -changeQuantity,
        previousQuantity: currentInventory,
        newQuantity: currentInventory - changeQuantity,
        reason: 'تراجع عن عملية سابقة / Reverted previous log',
        userEmail: userEmail,
        userName: userName,
        itemType: itemType,
        date: revertDate,
      );

      if (inventoryRef != null) {
        transaction.update(inventoryRef, {
          'quantity': FieldValue.increment(-changeQuantity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(sourceLogRef, {'isReverted': true});
      transaction.set(revertLogRef, reversingLog.toJson());
    });
  }
}

final inventoryLogRepositoryProvider = Provider<InventoryLogRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return InventoryLogRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final inventoryLogsStreamProvider = StreamProvider<List<InventoryLog>>((ref) {
  final repo = ref.watch(inventoryLogRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchLogs();
});

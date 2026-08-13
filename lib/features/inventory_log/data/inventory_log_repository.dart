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
        .withConverter<InventoryLog?>(
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
        )
        .orderBy('date', descending: true)
        // Note: FirestoreListView cannot easily filter out specific document IDs (like 'store_profile_doc') natively without breaking limit.
        // We will just return null for them and handle nulls in the builder.
        .where('date', isLessThanOrEqualTo: Timestamp.now()) as Query<InventoryLog>;
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

  Future<void> revertLog(InventoryLog log, {required String userEmail, required String userName}) async {
    if (log.isReverted) return;

    // 1. Mark original log as reverted
    await _logsRef.doc(log.id).update({'isReverted': true});

    // 2. Adjust inventory
    double currentInventory = 0.0;
    if (log.productId.isNotEmpty && log.changeQuantity != 0) {
      final productRef = _firestore.collection('products').doc(log.productId);
      final rawRef = _firestore.collection('raw_materials').doc(log.productId);
      
      final pDoc = await productRef.get(const GetOptions(source: Source.serverAndCache));
      if (pDoc.exists) {
        currentInventory = (pDoc.data()?['quantity'] as num?)?.toDouble() ?? 0.0;
        await productRef.update({
          'quantity': FieldValue.increment(-log.changeQuantity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final rDoc = await rawRef.get(const GetOptions(source: Source.serverAndCache));
        if (rDoc.exists) {
          currentInventory = (rDoc.data()?['quantity'] as num?)?.toDouble() ?? 0.0;
          await rawRef.update({
            'quantity': FieldValue.increment(-log.changeQuantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // 3. Create a reverting log
    final revertLog = InventoryLog(
      id: Uuid().v4(),
      merchantId: _merchantId,
      productId: log.productId,
      productName: log.productName,
      changeQuantity: -log.changeQuantity,
      previousQuantity: currentInventory,
      newQuantity: currentInventory - log.changeQuantity,
      reason: 'تراجع عن عملية سابقة / Reverted previous log',
      userEmail: userEmail,
      userName: userName,
      itemType: log.itemType,
      date: DateTime.now(),
    );
    await _logsRef.doc(revertLog.id).set(revertLog.toJson());
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


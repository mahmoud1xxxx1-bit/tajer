import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataMigrationService {
  final FirebaseFirestore _firestore;

  DataMigrationService(this._firestore);

  static const int _batchSize = 400;

  // Collections that live at the Firestore root and are scoped by merchantId.
  static const List<String> _rootMerchantCollections = [
    'products',
    'orders',
    'customers',
    'raw_materials',
    'shifts',
  ];

  // Collections that live under merchants/{merchantId}/...
  static const List<String> _merchantSubcollections = [
    'categories',
    'expenses',
    'inventory_logs',
    'suppliers',
    'payments',
    'notebook_books',
    'notebook_accounts',
    'notebook_categories',
    'notebook_people',
    'notebook_transactions',
  ];

  // Collections that live under users/{merchantId}/...
  static const List<String> _userSubcollections = [
    'employees',
    'notifications',
  ];

  /// Migrates the current Tajer merchant workspace from [oldMerchantId] to
  /// [newMerchantId].
  ///
  /// The source merchant subcollections are intentionally preserved. A guest
  /// merge is a one-time account transition, and retaining the source is safer
  /// than deleting it before every destination write is known to have
  /// completed. Root collections are moved by changing their merchantId only
  /// after all nested data has been copied successfully.
  ///
  /// Throws on failure so the caller can never report a successful merge when
  /// the data migration itself failed.
  Future<bool> migrateData(String oldMerchantId, String newMerchantId) async {
    if (oldMerchantId.isEmpty || newMerchantId.isEmpty) {
      throw ArgumentError('Merchant IDs must not be empty.');
    }
    if (oldMerchantId == newMerchantId) return true;

    try {
      // Copy path-scoped data first. The source remains intact, which makes the
      // operation safe to retry if a later batch fails.
      for (final collectionName in _merchantSubcollections) {
        await _copySubcollectionIfMissing(
          oldParent: _firestore.collection('merchants').doc(oldMerchantId),
          newParent: _firestore.collection('merchants').doc(newMerchantId),
          collectionName: collectionName,
          oldMerchantId: oldMerchantId,
          newMerchantId: newMerchantId,
        );
      }

      // Supplier transactions are nested one level deeper and must follow the
      // supplier document into the destination workspace.
      await _copySupplierTransactions(
        oldMerchantId: oldMerchantId,
        newMerchantId: newMerchantId,
      );

      for (final collectionName in _userSubcollections) {
        await _copySubcollectionIfMissing(
          oldParent: _firestore.collection('users').doc(oldMerchantId),
          newParent: _firestore.collection('users').doc(newMerchantId),
          collectionName: collectionName,
          oldMerchantId: oldMerchantId,
          newMerchantId: newMerchantId,
        );
      }

      // Root documents cannot be copied to another path because their document
      // ID already identifies the record globally. Move their ownership only
      // after every nested copy above has completed.
      for (final collectionName in _rootMerchantCollections) {
        await _moveRootCollectionOwnership(
          collectionName,
          oldMerchantId,
          newMerchantId,
        );
      }

      return true;
    } catch (e) {
      // Do not swallow migration failures. resolveMerge awaits this method, so
      // rethrowing prevents the UI from announcing a false success.
      throw Exception('Data migration failed: $e');
    }
  }

  Future<void> _moveRootCollectionOwnership(
    String collectionName,
    String oldMerchantId,
    String newMerchantId,
  ) async {
    while (true) {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('merchantId', isEqualTo: oldMerchantId)
          .limit(_batchSize)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'merchantId': newMerchantId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> _copySubcollectionIfMissing({
    required DocumentReference<Map<String, dynamic>> oldParent,
    required DocumentReference<Map<String, dynamic>> newParent,
    required String collectionName,
    required String oldMerchantId,
    required String newMerchantId,
  }) async {
    final oldSnapshot = await oldParent.collection(collectionName).get();
    if (oldSnapshot.docs.isEmpty) return;

    final newSnapshot = await newParent.collection(collectionName).get();
    final existingIds = newSnapshot.docs.map((doc) => doc.id).toSet();

    WriteBatch batch = _firestore.batch();
    var pendingWrites = 0;

    for (final doc in oldSnapshot.docs) {
      if (existingIds.contains(doc.id)) continue;

      final destination = newParent.collection(collectionName).doc(doc.id);
      batch.set(
        destination,
        _rewriteMerchantReferences(
          doc.data(),
          oldMerchantId,
          newMerchantId,
        ),
      );
      pendingWrites++;

      if (pendingWrites >= _batchSize) {
        await batch.commit();
        batch = _firestore.batch();
        pendingWrites = 0;
      }
    }

    if (pendingWrites > 0) {
      await batch.commit();
    }
  }

  Future<void> _copySupplierTransactions({
    required String oldMerchantId,
    required String newMerchantId,
  }) async {
    final oldSuppliers = await _firestore
        .collection('merchants')
        .doc(oldMerchantId)
        .collection('suppliers')
        .get();

    for (final supplier in oldSuppliers.docs) {
      final oldTransactions = await supplier.reference.collection('transactions').get();
      if (oldTransactions.docs.isEmpty) continue;

      final newTransactionsRef = _firestore
          .collection('merchants')
          .doc(newMerchantId)
          .collection('suppliers')
          .doc(supplier.id)
          .collection('transactions');
      final newTransactions = await newTransactionsRef.get();
      final existingIds = newTransactions.docs.map((doc) => doc.id).toSet();

      WriteBatch batch = _firestore.batch();
      var pendingWrites = 0;

      for (final transactionDoc in oldTransactions.docs) {
        if (existingIds.contains(transactionDoc.id)) continue;

        batch.set(
          newTransactionsRef.doc(transactionDoc.id),
          _rewriteMerchantReferences(
            transactionDoc.data(),
            oldMerchantId,
            newMerchantId,
          ),
        );
        pendingWrites++;

        if (pendingWrites >= _batchSize) {
          await batch.commit();
          batch = _firestore.batch();
          pendingWrites = 0;
        }
      }

      if (pendingWrites > 0) {
        await batch.commit();
      }
    }
  }

  Map<String, dynamic> _rewriteMerchantReferences(
    Map<String, dynamic> source,
    String oldMerchantId,
    String newMerchantId,
  ) {
    final data = Map<String, dynamic>.from(source);

    if (data['merchantId'] == oldMerchantId) {
      data['merchantId'] = newMerchantId;
    }
    if (data['merchantUid'] == oldMerchantId) {
      data['merchantUid'] = newMerchantId;
    }

    return data;
  }
}

final dataMigrationServiceProvider = Provider<DataMigrationService>((ref) {
  return DataMigrationService(FirebaseFirestore.instance);
});

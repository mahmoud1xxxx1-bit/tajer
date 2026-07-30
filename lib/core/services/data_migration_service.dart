import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataMigrationService {
  final FirebaseFirestore _firestore;

  DataMigrationService(this._firestore);

  /// Migrates all data belonging to [oldMerchantId] to [newMerchantId]
  /// Returns true if successful, false otherwise.
  Future<bool> migrateData(String oldMerchantId, String newMerchantId) async {
    try {
      final batch = _firestore.batch();
      int operationCount = 0;

      // Helper function to process collections
      Future<void> migrateCollection(String collectionName) async {
        final querySnapshot = await _firestore
            .collection(collectionName)
            .where('merchantId', isEqualTo: oldMerchantId)
            .get();

        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'merchantId': newMerchantId});
          operationCount++;
          
          // Firestore batch limit is 500 operations
          if (operationCount >= 490) {
            await batch.commit();
            operationCount = 0;
          }
        }
      }

      // 1. Migrate Products
      await migrateCollection('products');

      // 2. Migrate Orders
      await migrateCollection('orders');

      // 3. Migrate Customers
      await migrateCollection('customers');

      // 4. Migrate Suppliers
      await migrateCollection('suppliers');

      // 5. Migrate Expenses
      await migrateCollection('expenses');

      // 6. Migrate Inventory Logs
      // Inventory logs are nested under 'merchants' collection
      final inventoryLogsSnapshot = await _firestore
          .collection('merchants')
          .doc(oldMerchantId)
          .collection('inventory_logs')
          .get();

      for (var doc in inventoryLogsSnapshot.docs) {
        final newDocRef = _firestore
            .collection('merchants')
            .doc(newMerchantId)
            .collection('inventory_logs')
            .doc(doc.id);
        
        batch.set(newDocRef, {
          ...doc.data(),
          'merchantId': newMerchantId,
        });
        batch.delete(doc.reference);
        operationCount += 2; // one set, one delete

        if (operationCount >= 490) {
          await batch.commit();
          operationCount = 0;
        }
      }

      // Commit remaining operations
      if (operationCount > 0) {
        await batch.commit();
      }

      return true;
    } catch (e) {
      print("Data Migration Error: $e");
      return false;
    }
  }
}

final dataMigrationServiceProvider = Provider<DataMigrationService>((ref) {
  return DataMigrationService(FirebaseFirestore.instance);
});

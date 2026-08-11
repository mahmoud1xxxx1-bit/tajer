import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/core/services/branch_catalog_migration_bootstrap_service.dart';

void main() {
  group('Bootstrap Behavioral Tests', () {
    late FakeFirebaseFirestore firestore;
    late BranchCatalogMigrationBootstrapService service;
    final merchantId = 'merchant1';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = BranchCatalogMigrationBootstrapService(firestore);
    });

    test('A. Global Complete', () async {
      final globalStateRef = firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('global_catalog_migration_v1');

      await globalStateRef.set({'status': 'completed'});

      await service.runForOwner(merchantId: merchantId);

      // Assert 0 branch migration loops and 0 writes.
      // Since it early returns, branch_catalog_v1_main should not exist
      final branchMigState = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('branch_catalog_v1_main')
          .get();

      expect(branchMigState.exists, false);
    });

    test('B. Empty Merchant', () async {
      await service.runForOwner(merchantId: merchantId);

      final globalStateRef = firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('global_catalog_migration_v1');
      
      final globalState = await globalStateRef.get();
      expect(globalState.exists, true);
      expect(globalState.data()?['status'], 'completed');

      // Assert branch migration did not run (early returned due to empty collections)
      final branchMigState = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('branch_catalog_v1_main')
          .get();

      expect(branchMigState.exists, false);
    });

    test('C. Legacy Merchant', () async {
      await firestore.collection('products').doc('legacy_prod1').set({
        'name': 'Old Product',
        'merchantId': merchantId,
        'isArchived': false,
        'price': 10,
      });

      await service.runForOwner(merchantId: merchantId);

      // Assert branch copies successfully duplicate state
      final mainBranchProduct = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc('main')
          .collection('products')
          .doc('legacy_prod1')
          .get();
      
      expect(mainBranchProduct.exists, true);
      expect(mainBranchProduct.data()?['name'], 'Old Product');
      expect(mainBranchProduct.data()?['branchId'], 'main');

      // Assert global completion writes ONLY after full success
      final globalState = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('global_catalog_migration_v1')
          .get();
      
      expect(globalState.exists, true);
      expect(globalState.data()?['status'], 'completed');
    });

    test('D. New Branch After Global Complete', () async {
      // 1. First, global complete is achieved
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('migration_state')
          .doc('global_catalog_migration_v1')
          .set({'status': 'completed'});

      // 2. Create a branch post-global-completion
      final branchId = 'new_branch';
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .set({'name': 'New Branch'});

      // 3. Create native product (simulating user creating product in new branch)
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .doc('native_prod')
          .set({
        'name': 'Native Product',
        'isArchived': false,
        'branchId': branchId,
        'merchantId': merchantId,
      });

      // Assert all are immediately readable in the branch with 0 dependency on legacy fallback loops
      final nativeProd = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .doc('native_prod')
          .get();

      expect(nativeProd.exists, true);
      expect(nativeProd.data()?['name'], 'Native Product');
      
      // Also ensure that calling bootstrap again does not wipe or affect it
      await service.runForOwner(merchantId: merchantId);
      final checkNativeProd = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .doc('native_prod')
          .get();
      
      expect(checkNativeProd.exists, true);
    });
  });
}

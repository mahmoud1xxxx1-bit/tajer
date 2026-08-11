import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/action_center/data/action_center_repository.dart';
import 'package:tajer/features/action_center/domain/action_alert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/features/authentication/data/auth_repository.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/features/products/domain/raw_material.dart';
import 'package:tajer/features/action_center/application/action_center_evaluator.dart';

void main() {
  group('F12 Action Center Production Logic Tests', () {
    late FakeFirebaseFirestore firestore;
    late ActionCenterRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = ActionCenterRepository(firestore);
    });

    test('create logs new alert with fingerprint', () async {
      await repo.logAlert(
        merchantId: 'm1',
        branchId: 'b1',
        type: 'test_type',
        severity: 'high',
        sourceType: 'test',
        sourceId: '123',
      );

      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      for(final doc in snapshot.docs) {
        print(doc.data()['type']);
      } expect(snapshot.docs.length, 1);
      
      final alert = ActionAlert.fromJson(snapshot.docs.first.data()..['id'] = snapshot.docs.first.id);
      expect(alert.fingerprint, 'b1_test_type_test_123');
      expect(alert.status, 'open');
    });

    test('dedupe: same fingerprint while open is ignored', () async {
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');

      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      for(final doc in snapshot.docs) {
        print(doc.data()['type']);
      } expect(snapshot.docs.length, 1);
    });

    test('resolve: marks alert as resolved with timestamp', () async {
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');
      
      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      final alertId = snapshot.docs.first.id;

      await repo.resolveAlert('m1', alertId);

      final resolvedSnap = await firestore.collection('merchants').doc('m1').collection('alerts').doc(alertId).get();
      final resolvedAlert = ActionAlert.fromJson(resolvedSnap.data()!..['id'] = resolvedSnap.id);
      expect(resolvedAlert.status, 'resolved');
      expect(resolvedAlert.resolvedAt, isNotNull);
    });

    test('reopen: same fingerprint can open new alert if previous is resolved', () async {
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');
      
      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      final alertId = snapshot.docs.first.id;

      await repo.resolveAlert('m1', alertId);
      
      // Attempt to log again
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');

      final finalSnapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').get();
      expect(finalSnapshot.docs.length, 1);
    });
  });

  group('F12 Raw Material Evaluator Tests', () {
    late FakeFirebaseFirestore firestore;
    late ActionCenterRepository repo;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = ActionCenterRepository(firestore);
      
      container = ProviderContainer(
        overrides: [
          actionCenterRepositoryProvider.overrideWithValue(repo),
          appUserProvider.overrideWith((ref) => Stream.value(AppUser(id: 'm1', email: 'e', role: 'owner', merchantId: 'm1', createdAt: DateTime.now()))),
        ],
      );
      container.listen(appUserProvider, (_, __) {}); // Keep alive
    });

    test('raw material normal -> no alert', () async {
      await container.read(appUserProvider.future);
      final materials = [
        RawMaterial(id: 'rm1', name: 'Flour', merchantId: 'm1', initialQuantity: 50, unit: 'g', createdAt: DateTime.now(), updatedAt: DateTime.now(), quantity: 50, lowStockThreshold: 10, targetQuantity: 100, preferredSupplierId: 's1'),
      ];
      evaluateRawMaterials(container.read(providerForTestingRef), materials, 'b1');
      await Future.delayed(const Duration(milliseconds: 10)); // wait for async logAlert
      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').get();
      expect(snapshot.docs.length, 0);
    });

    test('raw material low -> one OPEN alert, re-evaluation -> no duplicate, recovery -> RESOLVED, low again -> recurrent', () async {
      await container.read(appUserProvider.future);
      // 1. Low
      var materials = [
        RawMaterial(id: 'rm1', name: 'Flour', merchantId: 'm1', initialQuantity: 50, unit: 'g', createdAt: DateTime.now(), updatedAt: DateTime.now(), quantity: 5, lowStockThreshold: 10, targetQuantity: 100, preferredSupplierId: 's1'),
      ];
      evaluateRawMaterials(container.read(providerForTestingRef), materials, 'b1');
      await Future.delayed(const Duration(milliseconds: 10));
      
      var snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').where('type', isEqualTo: 'low_stock').get();
      expect(snapshot.docs.length, 1);
      final alertId1 = snapshot.docs.first.id;

      // 2. Re-evaluation while still low (dedupe)
      evaluateRawMaterials(container.read(providerForTestingRef), materials, 'b1');
      await Future.delayed(const Duration(milliseconds: 10));
      snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').where('type', isEqualTo: 'low_stock').get();
      expect(snapshot.docs.length, 1, reason: 'Should dedupe');
      
      // 3. Recovery
      materials = [
        RawMaterial(id: 'rm1', name: 'Flour', merchantId: 'm1', initialQuantity: 50, unit: 'g', createdAt: DateTime.now(), updatedAt: DateTime.now(), quantity: 50, lowStockThreshold: 10, targetQuantity: 100, preferredSupplierId: 's1'),
      ];
      evaluateRawMaterials(container.read(providerForTestingRef), materials, 'b1');
      await Future.delayed(const Duration(milliseconds: 10));
      snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').where('type', isEqualTo: 'low_stock').get();
      expect(snapshot.docs.length, 0, reason: 'Should be resolved');
      
      // 4. Low again (recurrent)
      materials = [
        RawMaterial(id: 'rm1', name: 'Flour', merchantId: 'm1', initialQuantity: 50, unit: 'g', createdAt: DateTime.now(), updatedAt: DateTime.now(), quantity: 2, lowStockThreshold: 10, targetQuantity: 100, preferredSupplierId: 's1'),
      ];
      evaluateRawMaterials(container.read(providerForTestingRef), materials, 'b1');
      await Future.delayed(const Duration(milliseconds: 10));
      snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').where('type', isEqualTo: 'low_stock').get();
      expect(snapshot.docs.length, 1, reason: 'Should open a new recurrent alert');
      expect(snapshot.docs.first.id, alertId1, reason: 'Must reuse the same document ID');
    });

    test('Branch A alert cannot be confused with same rawMaterialId in Branch B', () async {
      await container.read(appUserProvider.future);
      // Branch A is low
      final materialsA = [
        RawMaterial(id: 'rm1', name: 'Flour', merchantId: 'm1', initialQuantity: 50, unit: 'g', createdAt: DateTime.now(), updatedAt: DateTime.now(), quantity: 5, lowStockThreshold: 10, targetQuantity: 100, preferredSupplierId: 's1'),
      ];
      evaluateRawMaterials(container.read(providerForTestingRef), materialsA, 'b1');
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Branch B is normal
      final materialsB = [
        RawMaterial(id: 'rm1', name: 'Flour', merchantId: 'm1', initialQuantity: 50, unit: 'g', createdAt: DateTime.now(), updatedAt: DateTime.now(), quantity: 50, lowStockThreshold: 10, targetQuantity: 100, preferredSupplierId: 's1'),
      ];
      evaluateRawMaterials(container.read(providerForTestingRef), materialsB, 'b2');
      await Future.delayed(const Duration(milliseconds: 10));
      
      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').where('type', isEqualTo: 'low_stock').get();
      expect(snapshot.docs.length, 1);
      
      final alert = ActionAlert.fromJson(snapshot.docs.first.data()..['id'] = snapshot.docs.first.id);
      expect(alert.fingerprint, 'b1_low_stock_raw_material_rm1');
    });
  });
}

final providerForTestingRef = Provider((ref) => ref);

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/models/plan_tier.dart';
import 'package:tajer/core/services/entitlement_integration.dart';

void main() {
  setUp(() => EntitlementIntegration.injectTestTier(PlanTier.free));
  tearDown(EntitlementIntegration.clearTestTier);

  test('two concurrent consumes at 29/30 must allow exactly one', () async {
    final db = FakeFirebaseFirestore();
    final usageRef = db.collection('merchants').doc('m1').collection('entitlement_usage').doc('global_orders_lifetime');
    await usageRef.set({'count': 29, 'branchId': 'global', 'resourceType': 'orders', 'periodKey': 'lifetime'});

    final futures = List.generate(2, (_) async {
      try {
        await EntitlementIntegration.checkAndConsumeQuota(
          firestore: db,
          merchantId: 'm1',
          branchId: 'main',
          resourceType: 'orders',
          plan: 'free',
        );
        return true;
      } catch (_) {
        return false;
      }
    });

    final results = await Future.wait(futures);
    expect(results.where((v) => v).length, 1,
        reason: 'At lifetime usage 29, only one of two concurrent requests may consume the last slot.');
    final snap = await usageRef.get();
    expect((snap.data()?['count'] as num?)?.toInt(), 30);
  });

  test('quota API cannot exceed 30 after repeated consume attempts', () async {
    final db = FakeFirebaseFirestore();
    final usageRef = db.collection('merchants').doc('m1').collection('entitlement_usage').doc('global_orders_lifetime');
    await usageRef.set({'count': 29, 'branchId': 'global', 'resourceType': 'orders', 'periodKey': 'lifetime'});

    await EntitlementIntegration.checkAndConsumeQuota(
      firestore: db, merchantId: 'm1', branchId: 'main', resourceType: 'orders', plan: 'free');
    await expectLater(
      EntitlementIntegration.checkAndConsumeQuota(
        firestore: db, merchantId: 'm1', branchId: 'main', resourceType: 'orders', plan: 'free'),
      throwsA(isA<Exception>()),
    );
    final snap = await usageRef.get();
    expect((snap.data()?['count'] as num?)?.toInt(), 30);
  });
}

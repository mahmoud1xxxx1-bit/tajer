import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/core/models/subscription_policy.dart';
import 'package:tajer/core/services/entitlement_integration.dart';
import 'package:tajer/core/models/plan_tier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  const merchantId = 'test_merchant';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    EntitlementIntegration.clearTestTier();
  });

  Future<void> setupPlan(String plan) async {
    await firestore.collection('merchants').doc(merchantId).set({'plan': plan});
  }

  group('Free Plan Limits', () {
    test('Free orders 1-29 succeed', () async {
      await setupPlan('free');
      // Simulate 29 orders
      for (int i = 0; i < 29; i++) {
        await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: merchantId,
          branchId: 'main',
          resourceType: 'orders',
        );
      }
      final usage = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('global_orders_lifetime')
          .get();
      expect(usage.data()?['count'], 29);
    });

    test('Free order 30 succeeds, order 31 fails', () async {
      await setupPlan('free');
      
      // Setup 29 orders
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('global_orders_lifetime')
          .set({'count': 29});

      // Order 30 should succeed
      await EntitlementIntegration.checkAndConsumeQuota(
        firestore: firestore,
        merchantId: merchantId,
        branchId: 'main',
        resourceType: 'orders',
      );

      final usage = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('global_orders_lifetime')
          .get();
      expect(usage.data()?['count'], 30);

      // Order 31 should fail
      expect(
        () => EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: merchantId,
          branchId: 'main',
          resourceType: 'orders',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('limit_reached_for_plan'))),
      );
    });

    test('Month change does not reset lifetime quota', () async {
      await setupPlan('free');
      
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('global_orders_lifetime')
          .set({'count': 30});

      // Month doesn't matter because periodKey is strictly 'lifetime'
      expect(
        () => EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: merchantId,
          branchId: 'main',
          resourceType: 'orders',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Trial Branch Limits', () {
    test('Trial branch order 1-3 succeeds, 4 fails', () async {
      await setupPlan('free');
      // Create a trial branch (branch 2 -> index 1)
      await firestore.collection('merchants').doc(merchantId).collection('branches').doc('main').set({'createdAt': FieldValue.serverTimestamp()});
      await firestore.collection('merchants').doc(merchantId).collection('branches').doc('branch_2').set({'createdAt': FieldValue.serverTimestamp()});
      
      for (int i = 0; i < 3; i++) {
        await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: merchantId,
          branchId: 'branch_2',
          resourceType: 'orders',
        );
      }

      // 4th order fails specifically due to branch limit
      expect(
        () => EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: merchantId,
          branchId: 'branch_2',
          resourceType: 'orders',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('limit_reached_for_plan'))),
      );

      // Verify global count reflects the 3 orders
      final globalUsage = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('global_orders_lifetime')
          .get();
      expect(globalUsage.data()?['count'], 3);
    });
  });

  group('Paid Plans Bypass Limits', () {
    test('Main plan bypasses global Free 30 limit', () async {
      await setupPlan('main');
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('main_orders_lifetime')
          .set({'count': 500});

      // Should succeed unconditionally for main branch
      await EntitlementIntegration.checkAndConsumeQuota(
        firestore: firestore,
        merchantId: merchantId,
        branchId: 'main',
        resourceType: 'orders',
      );
      
      final usage = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('main_orders_lifetime')
          .get();
      expect(usage.data()?['count'], 500);
    });

    test('Multi plan bypasses free limit for production branches', () async {
      await setupPlan('multibranch');
      
      await firestore.collection('merchants').doc(merchantId).collection('branches').doc('main').set({'createdAt': FieldValue.serverTimestamp()});
      await firestore.collection('merchants').doc(merchantId).collection('branches').doc('branch_2').set({'createdAt': FieldValue.serverTimestamp()});
      
      await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('branch_2_orders_lifetime')
          .set({'count': 50});

      // Should succeed unconditionally for additional production branch
      await EntitlementIntegration.checkAndConsumeQuota(
        firestore: firestore,
        merchantId: merchantId,
        branchId: 'branch_2',
        resourceType: 'orders',
      );
      
      final usage = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('branch_2_orders_lifetime')
          .get();
      expect(usage.data()?['count'], 50);
    });
  });

  group('Legacy Resolution', () {
    test('legacy main -> PlanTier.main', () {
      expect(SubscriptionPolicy.resolveLegacyPlan('main'), PlanTier.main);
    });
    
    test('legacy multibranch -> PlanTier.multiBranch', () {
      expect(SubscriptionPolicy.resolveLegacyPlan('multibranch'), PlanTier.multiBranch);
    });
  });
}

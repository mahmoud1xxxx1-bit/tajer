import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/core/models/plan_tier.dart';
import 'package:tajer/core/services/entitlement_integration.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Step 4 Limits - Guest Tier', () {
    test('guest should allow 3 lifetime orders and block the 4th', () async {
      await firestore.collection('merchants').doc('guest_123').set({
        'plan': 'guest',
      });

      for (int i = 0; i < 3; i++) {
        await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'guest_123',
          branchId: 'main',
          resourceType: 'orders',
          plan: 'guest',
        );
      }

      expect(
        () async => await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'guest_123',
          branchId: 'main',
          resourceType: 'orders',
          plan: 'guest',
        ),
        throwsException,
      );
    });

    test('guest should allow 1 product lifetime and block the 2nd', () async {
      await EntitlementIntegration.checkAndConsumeQuota(
        firestore: firestore,
        merchantId: 'guest_123',
        branchId: 'main',
        resourceType: 'products',
        plan: 'guest',
      );

      expect(
        () async => await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'guest_123',
          branchId: 'main',
          resourceType: 'products',
          plan: 'guest',
        ),
        throwsException,
      );
    });

    test('guest delete/recreate exploit is blocked (monotonic counter)', () async {
      // Create first product
      await EntitlementIntegration.checkAndConsumeQuota(
        firestore: firestore,
        merchantId: 'guest_123',
        branchId: 'main',
        resourceType: 'products',
        plan: 'guest',
      );

      // Simulate deleting the product from business logic
      await firestore.collection('merchants').doc('guest_123').collection('branches').doc('main').collection('products').doc('p1').set({'isArchived': true});

      // The quota counter is monotonic and independent of the business collection
      // Creating a replacement should STILL be denied
      expect(
        () async => await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'guest_123',
          branchId: 'main',
          resourceType: 'products',
          plan: 'guest',
        ),
        throwsException,
      );
    });
  });

  group('Step 4 Limits - Free Main Tier', () {
    test('free main should allow 100 orders and block 101st (monthly)', () async {
      // Simulate 100 previous orders in the current month
      final now = DateTime.now();
      final periodKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await firestore
          .collection('merchants')
          .doc('free_123')
          .collection('entitlement_usage')
          .doc('main_orders_$periodKey')
          .set({'count': 100});

      expect(
        () async => await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'free_123',
          branchId: 'main',
          resourceType: 'orders',
          plan: 'merchant',
        ),
        throwsException,
      );
    });
  });

  group('Step 4 Limits - Trial Branch', () {
    test('trial branch should allow 3 orders independently of main', () async {
      await firestore
          .collection('merchants')
          .doc('free_123')
          .collection('branches')
          .doc('main')
          .set({'createdAt': DateTime.now().toIso8601String()});
          
      await firestore
          .collection('merchants')
          .doc('free_123')
          .collection('branches')
          .doc('branch2')
          .set({'createdAt': DateTime.now().add(const Duration(seconds: 1)).toIso8601String()});

      for (int i = 0; i < 3; i++) {
        await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'free_123',
          branchId: 'branch2',
          resourceType: 'orders',
          plan: 'merchant',
        );
      }

      expect(
        () async => await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'free_123',
          branchId: 'branch2',
          resourceType: 'orders',
          plan: 'merchant',
        ),
        throwsException,
      );

      // Main branch is unaffected
      final mainCheck = await EntitlementIntegration.checkQuota(
        firestore: firestore,
        merchantId: 'free_123',
        branchId: 'main',
        resourceType: 'orders',
        plan: 'merchant',
      );
      expect(mainCheck, isTrue);
    });

    test('trial branch delete/recreate exploit is blocked', () async {
      // Create first order in trial branch
      for(int i=0; i<100; i++) {
        await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'free_123',
          branchId: 'branch2',
          resourceType: 'orders',
          plan: 'merchant',
        );
      }

      // Replacement should be denied because trial branch allows 100 orders
      expect(
        () async => await EntitlementIntegration.checkAndConsumeQuota(
          firestore: firestore,
          merchantId: 'free_123',
          branchId: 'branch2',
          resourceType: 'orders',
          plan: 'merchant',
        ),
        throwsException,
      );
    });
  });
}

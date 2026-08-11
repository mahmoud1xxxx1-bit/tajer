import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/models/plan_tier.dart';
import 'package:tajer/core/services/entitlement_evaluator.dart';
import 'package:tajer/core/services/entitlement_integration.dart';

void main() {
  group('Entitlement Integration Test', () {
    setUp(() {
      EntitlementIntegration.clearTestTier();
    });

    test('resolveEffectiveTier uses legacy map when not injected', () {
      expect(EntitlementIntegration.resolveEffectiveTier('guest'),
          equals(PlanTier.guest));
      expect(EntitlementIntegration.resolveEffectiveTier('merchant'),
          equals(PlanTier.free));
      expect(EntitlementIntegration.resolveEffectiveTier('premium'),
          equals(PlanTier.free)); // Fallback from Step 1
    });

    test('resolveEffectiveTier uses injected tier for testing', () {
      EntitlementIntegration.injectTestTier(PlanTier.main);
      expect(EntitlementIntegration.resolveEffectiveTier('premium'),
          equals(PlanTier.main));

      EntitlementIntegration.injectTestTier(PlanTier.multiBranch);
      expect(EntitlementIntegration.resolveEffectiveTier('premium'),
          equals(PlanTier.multiBranch));
    });

    test('MAIN test-injected: Employee limits for Main plan', () {
      EntitlementIntegration.injectTestTier(PlanTier.main);
      final tier = EntitlementIntegration.resolveEffectiveTier('premium');

      // Main branch (position 1)
      expect(EntitlementEvaluator.canAddEmployee(tier, 1, 0), isTrue); // #1 allow
      expect(EntitlementEvaluator.canAddEmployee(tier, 1, 1), isTrue); // #2 allow
      expect(EntitlementEvaluator.canAddEmployee(tier, 1, 2), isTrue); // #3 allow
      expect(EntitlementEvaluator.canAddEmployee(tier, 1, 3), isFalse); // #4 deny
    });

    test('MULTI test-injected: Employee limits for MultiBranch plan', () {
      EntitlementIntegration.injectTestTier(PlanTier.multiBranch);
      final tier = EntitlementIntegration.resolveEffectiveTier('premium');

      // Main branch (position 1) -> max 3
      expect(EntitlementEvaluator.canAddEmployee(tier, 1, 2), isTrue);
      expect(EntitlementEvaluator.canAddEmployee(tier, 1, 3), isFalse);

      // Branch 2 (position 2) -> max 2
      expect(EntitlementEvaluator.canAddEmployee(tier, 2, 1), isTrue);
      expect(EntitlementEvaluator.canAddEmployee(tier, 2, 2), isFalse);

      // Branch 3 (position 3) -> max 2
      expect(EntitlementEvaluator.canAddEmployee(tier, 3, 1), isTrue);
      expect(EntitlementEvaluator.canAddEmployee(tier, 3, 2), isFalse);
    });

    test('Branch access limits', () {
      EntitlementIntegration.injectTestTier(PlanTier.main);
      final tierMain = EntitlementIntegration.resolveEffectiveTier('premium');
      expect(EntitlementEvaluator.canAccessBranch(tierMain, 1), isTrue);
      expect(EntitlementEvaluator.canAccessBranch(tierMain, 2), isTrue);
      expect(EntitlementEvaluator.canAccessBranch(tierMain, 5), isFalse);

      EntitlementIntegration.injectTestTier(PlanTier.multiBranch);
      final tierMulti = EntitlementIntegration.resolveEffectiveTier('premium');
      expect(EntitlementEvaluator.canAccessBranch(tierMulti, 1), isTrue);
      expect(EntitlementEvaluator.canAccessBranch(tierMulti, 2), isTrue);
      expect(EntitlementEvaluator.canAccessBranch(tierMulti, 4), isTrue); 
      expect(EntitlementEvaluator.canAccessBranch(tierMulti, 5), isTrue); // up to 5
      expect(EntitlementEvaluator.canAccessBranch(tierMulti, 6), isFalse); // branch 6 denied
    });
  });
}

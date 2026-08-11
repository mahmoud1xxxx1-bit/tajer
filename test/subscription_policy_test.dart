import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/models/plan_tier.dart';
import 'package:tajer/core/models/branch_mode.dart';
import 'package:tajer/core/models/subscription_policy.dart';

void main() {
  group('Subscription Policy Pure Logic Tests', () {
    test('Guest Tier Limits', () {
      final limits = SubscriptionPolicy.getBranchLimits(PlanTier.guest, 0);
      expect(limits.ordersLifetime, 3);
      expect(limits.products, 1);
      expect(limits.employees, 0);
      
      expect(SubscriptionPolicy.getMaxAdditionalBranches(PlanTier.guest), 0);
    });

    test('Free Tier Limits', () {
      final limits = SubscriptionPolicy.getBranchLimits(PlanTier.free, 0);
      expect(limits.ordersMonthly, 100);
      expect(limits.products, 10);
      expect(limits.categories, 5);
      expect(limits.customers, 10);
      expect(limits.suppliers, 5);
      expect(limits.expensesMonthly, 10);
      expect(limits.rawMaterials, 10);
      expect(limits.employees, 0);
      
      expect(SubscriptionPolicy.getMaxAdditionalBranches(PlanTier.free), 3);
    });

    test('Trial Branch Limits', () {
      final limits = SubscriptionPolicy.getBranchLimits(PlanTier.free, 1);
      expect(limits.ordersLifetime, 3);
      expect(limits.products, 1);
      expect(limits.categories, 1);
      expect(limits.customers, 1);
      expect(limits.suppliers, 1);
      expect(limits.expensesLifetime, 1);
      expect(limits.rawMaterials, 1);
      expect(limits.employees, 0);
    });

    test('Main Tier Limits', () {
      final limits = SubscriptionPolicy.getBranchLimits(PlanTier.main, 0);
      expect(limits.ordersLifetime, null);
      expect(limits.ordersMonthly, null);
      expect(limits.employees, 3);
      
      expect(SubscriptionPolicy.getMaxAdditionalBranches(PlanTier.main), 3);

      final trialLimits = SubscriptionPolicy.getBranchLimits(PlanTier.main, 1);
      expect(trialLimits.ordersLifetime, 3);
      expect(trialLimits.products, 1);
      expect(trialLimits.categories, 1);
      expect(trialLimits.customers, 1);
      expect(trialLimits.suppliers, 1);
      expect(trialLimits.expensesLifetime, 1);
      expect(trialLimits.rawMaterials, 1);
      expect(trialLimits.employees, 0);
    });

    test('MultiBranch Tier Limits', () {
      // 4 total branches means max additional branches = 3
      expect(SubscriptionPolicy.getMaxAdditionalBranches(PlanTier.multiBranch), 3);
      
      final mainLimits = SubscriptionPolicy.getBranchLimits(PlanTier.multiBranch, 0);
      expect(mainLimits.employees, 3);
      expect(mainLimits.ordersLifetime, null);
      
      final additionalLimits = SubscriptionPolicy.getBranchLimits(PlanTier.multiBranch, 1);
      expect(additionalLimits.employees, 2);
      expect(additionalLimits.ordersLifetime, null);
    });

    test('Branch Mode Matrix', () {
      // Guest
      expect(SubscriptionPolicy.getBranchMode(PlanTier.guest, 0), BranchMode.mainLimited);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.guest, 1), BranchMode.unavailable);
      
      // Free
      expect(SubscriptionPolicy.getBranchMode(PlanTier.free, 0), BranchMode.mainLimited);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.free, 1), BranchMode.trial);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.free, 2), BranchMode.trial);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.free, 3), BranchMode.trial);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.free, 4), BranchMode.unavailable); // Branch 5
      
      // Main
      expect(SubscriptionPolicy.getBranchMode(PlanTier.main, 0), BranchMode.production);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.main, 1), BranchMode.trial);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.main, 2), BranchMode.trial);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.main, 3), BranchMode.trial);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.main, 4), BranchMode.unavailable); // Branch 5
      
      // MultiBranch
      expect(SubscriptionPolicy.getBranchMode(PlanTier.multiBranch, 0), BranchMode.production);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.multiBranch, 1), BranchMode.production);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.multiBranch, 2), BranchMode.production);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.multiBranch, 3), BranchMode.production);
      expect(SubscriptionPolicy.getBranchMode(PlanTier.multiBranch, 4), BranchMode.unavailable); // Branch 5
    });

    test('Legacy Resolver', () {
      expect(SubscriptionPolicy.resolveLegacyPlan('guest'), PlanTier.guest);
      expect(SubscriptionPolicy.resolveLegacyPlan('merchant'), PlanTier.free);
      expect(SubscriptionPolicy.resolveLegacyPlan('premium'), PlanTier.free);
      expect(SubscriptionPolicy.resolveLegacyPlan('pro'), PlanTier.free);
      expect(SubscriptionPolicy.resolveLegacyPlan('unknown'), PlanTier.free);
      expect(SubscriptionPolicy.resolveLegacyPlan(null), PlanTier.free);
    });
  });
}

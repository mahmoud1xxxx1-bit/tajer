import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/models/plan_tier.dart';
import 'package:tajer/core/models/branch_mode.dart';
import 'package:tajer/core/services/entitlement_evaluator.dart';

void main() {
  group('Entitlement Evaluator Pure Logic', () {
    test('Guest Entitlement', () {
      expect(EntitlementEvaluator.canAccessBranch(PlanTier.guest, 1), isTrue);
      expect(EntitlementEvaluator.branchMode(PlanTier.guest, 1), BranchMode.mainLimited);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.guest, 1), 0);
      
      expect(EntitlementEvaluator.canAccessBranch(PlanTier.guest, 2), isFalse);
      expect(EntitlementEvaluator.branchMode(PlanTier.guest, 2), BranchMode.unavailable);
    });

    test('Free Entitlement', () {
      expect(EntitlementEvaluator.canAccessBranch(PlanTier.free, 1), isTrue);
      expect(EntitlementEvaluator.branchMode(PlanTier.free, 1), BranchMode.mainLimited);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.free, 1), 0);

      expect(EntitlementEvaluator.canAccessBranch(PlanTier.free, 2), isTrue);
      expect(EntitlementEvaluator.branchMode(PlanTier.free, 2), BranchMode.trial);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.free, 2), 0);
      
      expect(EntitlementEvaluator.canAccessBranch(PlanTier.free, 3), isTrue);
      expect(EntitlementEvaluator.canAccessBranch(PlanTier.free, 4), isTrue);

      expect(EntitlementEvaluator.canAccessBranch(PlanTier.free, 5), isFalse);
    });

    test('Main Entitlement', () {
      expect(EntitlementEvaluator.branchMode(PlanTier.main, 1), BranchMode.production);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.main, 1), 3);

      expect(EntitlementEvaluator.branchMode(PlanTier.main, 2), BranchMode.trial);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.main, 2), 0);
      
      expect(EntitlementEvaluator.branchMode(PlanTier.main, 3), BranchMode.trial);
      expect(EntitlementEvaluator.branchMode(PlanTier.main, 4), BranchMode.trial);

      expect(EntitlementEvaluator.canAccessBranch(PlanTier.main, 5), isFalse);
    });

    test('MultiBranch Entitlement', () {
      expect(EntitlementEvaluator.branchMode(PlanTier.multiBranch, 1), BranchMode.production);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.multiBranch, 1), 3);

      expect(EntitlementEvaluator.branchMode(PlanTier.multiBranch, 2), BranchMode.production);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.multiBranch, 2), 2);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.multiBranch, 3), 2);
      expect(EntitlementEvaluator.maxEmployeesForBranch(PlanTier.multiBranch, 4), 2);

      expect(EntitlementEvaluator.canAccessBranch(PlanTier.multiBranch, 5), isTrue);
      expect(EntitlementEvaluator.canAccessBranch(PlanTier.multiBranch, 6), isFalse);
    });

    test('Employee Addition Logic Boundary Tests', () {
      // Main tier, main branch (max 3)
      expect(EntitlementEvaluator.canAddEmployee(PlanTier.main, 1, 2), isTrue);
      expect(EntitlementEvaluator.canAddEmployee(PlanTier.main, 1, 3), isFalse);

      // Multi branch, additional branch (max 2)
      expect(EntitlementEvaluator.canAddEmployee(PlanTier.multiBranch, 2, 1), isTrue);
      expect(EntitlementEvaluator.canAddEmployee(PlanTier.multiBranch, 2, 2), isFalse);

      // Invalid inputs
      expect(EntitlementEvaluator.canAddEmployee(PlanTier.main, 0, 0), isFalse); // branch 0
      expect(EntitlementEvaluator.canAddEmployee(PlanTier.main, 5, 0), isFalse); // branch 5
      expect(EntitlementEvaluator.canAddEmployee(PlanTier.main, 1, -1), isFalse); // negative employees
    });
  });
}

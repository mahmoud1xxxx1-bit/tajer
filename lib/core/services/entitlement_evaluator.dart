import '../models/plan_tier.dart';
import '../models/branch_mode.dart';
import '../models/subscription_policy.dart';

class EntitlementEvaluator {
  /// Evaluates if a given branch position (1-based, 1=Main) is accessible under the given tier.
  static bool canAccessBranch(PlanTier tier, int branchPosition) {
    if (branchPosition < 1 || branchPosition > 5) return false;
    
    if (branchPosition == 1) {
      return true; // Main is always available for all tiers
    }
    
    if (branchPosition == 5) {
      return tier == PlanTier.multiBranch;
    }
    
    // positions 2, 3, 4
    if (tier == PlanTier.guest) return false;
    return true; // free, main, multiBranch can access 2-4 (as trial or production)
  }

  /// Evaluates the commercial mode of a branch position.
  static BranchMode branchMode(PlanTier tier, int branchPosition) {
    if (!canAccessBranch(tier, branchPosition)) {
      return BranchMode.unavailable;
    }
    
    // Convert 1-based position to 0-based index for SubscriptionPolicy
    return SubscriptionPolicy.getBranchMode(tier, branchPosition - 1);
  }

  /// Returns the maximum allowed employees for a given branch position.
  static int maxEmployeesForBranch(PlanTier tier, int branchPosition) {
    if (!canAccessBranch(tier, branchPosition)) {
      return 0;
    }
    
    // Convert 1-based position to 0-based index for SubscriptionPolicy
    return SubscriptionPolicy.getBranchLimits(tier, branchPosition - 1).employees;
  }

  /// Evaluates if a new employee can be added to the given branch position.
  static bool canAddEmployee(PlanTier tier, int branchPosition, int currentEmployeeCount) {
    if (currentEmployeeCount < 0) return false;
    if (!canAccessBranch(tier, branchPosition)) return false;
    
    final maxAllowed = maxEmployeesForBranch(tier, branchPosition);
    return currentEmployeeCount < maxAllowed;
  }
}

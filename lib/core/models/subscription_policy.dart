import 'plan_tier.dart';
import 'branch_mode.dart';

class BranchLimits {
  final int? ordersLifetime;
  final int? ordersMonthly;
  final int products;
  final int categories;
  final int customers;
  final int suppliers;
  final int? expensesMonthly;
  final int? expensesLifetime;
  final int rawMaterials;
  final int employees;

  const BranchLimits({
    this.ordersLifetime,
    this.ordersMonthly,
    required this.products,
    required this.categories,
    required this.customers,
    required this.suppliers,
    this.expensesMonthly,
    this.expensesLifetime,
    required this.rawMaterials,
    required this.employees,
  });

  const BranchLimits.unlimited({
    this.ordersLifetime,
    this.ordersMonthly,
    this.products = -1,
    this.categories = -1,
    this.customers = -1,
    this.suppliers = -1,
    this.expensesMonthly,
    this.expensesLifetime,
    this.rawMaterials = -1,
    this.employees = -1,
  });
}

class SubscriptionPolicy {
  // GUEST
  static const BranchLimits guestMainLimits = BranchLimits(
    ordersLifetime: 3,
    products: 1,
    categories: 1,
    customers: 1,
    suppliers: 1,
    expensesLifetime: 1,
    rawMaterials: 1,
    employees: 0,
  );

  // FREE
  static const BranchLimits freeMainLimits = BranchLimits(
    ordersMonthly: 100,
    products: 10,
    categories: 5,
    customers: 10,
    suppliers: 5,
    expensesMonthly: 10,
    rawMaterials: 10,
    employees: 0,
  );

  static const BranchLimits trialBranchLimits = BranchLimits(
    ordersLifetime: 3,
    products: 1,
    categories: 1,
    customers: 1,
    suppliers: 1,
    expensesLifetime: 1,
    rawMaterials: 1,
    employees: 0,
  );

  // MAIN
  static const BranchLimits mainTierMainLimits = BranchLimits.unlimited(
    employees: 3,
  );
  
  // MULTI_BRANCH
  static const BranchLimits multiBranchMainLimits = BranchLimits.unlimited(
    employees: 3,
  );
  static const BranchLimits multiBranchAdditionalLimits = BranchLimits.unlimited(
    employees: 2,
  );

  static int getMaxAdditionalBranches(PlanTier tier) {
    switch (tier) {
      case PlanTier.guest:
        return 0;
      case PlanTier.free:
        return 3;
      case PlanTier.main:
        return 3;
      case PlanTier.multiBranch:
        return 3; // total 4 branches means 3 additional
    }
  }

  // Pure logic for branch mode
  static BranchMode getBranchMode(PlanTier tier, int branchIndex) {
    if (branchIndex == 0) {
      // Main branch
      switch (tier) {
        case PlanTier.guest:
        case PlanTier.free:
          return BranchMode.mainLimited;
        case PlanTier.main:
        case PlanTier.multiBranch:
          return BranchMode.production;
      }
    } else if (branchIndex >= 1 && branchIndex <= 3) {
      // Additional branch (index 1, 2, 3 corresponds to branch 2, 3, 4)
      switch (tier) {
        case PlanTier.guest:
          return BranchMode.unavailable;
        case PlanTier.free:
        case PlanTier.main:
          return BranchMode.trial;
        case PlanTier.multiBranch:
          return BranchMode.production;
      }
    }
    
    // Branch 5 or more (index 4+)
    return BranchMode.unavailable;
  }

  static BranchLimits getBranchLimits(PlanTier tier, int branchIndex) {
    final mode = getBranchMode(tier, branchIndex);
    switch (mode) {
      case BranchMode.mainLimited:
        if (tier == PlanTier.guest) return guestMainLimits;
        return freeMainLimits;
      case BranchMode.trial:
        return trialBranchLimits;
      case BranchMode.production:
        if (tier == PlanTier.multiBranch && branchIndex > 0) {
          return multiBranchAdditionalLimits;
        }
        return mainTierMainLimits;
      case BranchMode.unavailable:
        return const BranchLimits(
          ordersLifetime: 0,
          products: 0,
          categories: 0,
          customers: 0,
          suppliers: 0,
          expensesLifetime: 0,
          rawMaterials: 0,
          employees: 0,
        );
    }
  }

  // Legacy resolver
  static PlanTier resolveLegacyPlan(String? planString) {
    if (planString == null) return PlanTier.free;
    
    switch (planString.toLowerCase()) {
      case 'guest':
        return PlanTier.guest;
      case 'merchant':
      case 'premium':
      case 'pro':
      default:
        return PlanTier.free;
    }
  }
}

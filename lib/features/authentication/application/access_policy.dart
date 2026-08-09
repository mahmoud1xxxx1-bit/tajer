import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_identity.dart';

class AccessPolicy {
  final SessionIdentity? identity;

  const AccessPolicy(this.identity);

  bool get isReady => identity != null;
  bool get isOwnerLike => identity?.isOwnerLike ?? false;
  bool get isEmployee => identity?.role == 'employee';

  bool _perm(String permission) => identity?.hasPermission(permission) ?? false;

  bool get hasAssignedBranch {
    final current = identity;
    if (current == null) return false;
    if (current.isOwnerLike) return true;
    return current.activeBranchId.isNotEmpty &&
        current.assignedBranchIds.contains(current.activeBranchId);
  }

  bool get canCreateOrders => hasAssignedBranch && _perm('can_create_orders');
  bool get canViewOwnOrders => hasAssignedBranch;
  bool get canViewAllOrders =>
      hasAssignedBranch && _perm('can_view_all_orders');
  bool get canViewCustomers =>
      hasAssignedBranch && _perm('can_manage_customers');
  bool get canManageCustomers =>
      hasAssignedBranch && _perm('can_manage_customers');
  bool get canViewExpenses => hasAssignedBranch && _perm('can_manage_expenses');
  bool get canManageExpenses =>
      hasAssignedBranch && _perm('can_manage_expenses');
  bool get canViewInventory =>
      hasAssignedBranch &&
      (_perm('can_manage_inventory') || _perm('can_create_orders'));
  bool get canManageInventory =>
      hasAssignedBranch && _perm('can_manage_inventory');
  bool get canViewRawMaterials => isOwnerLike && _perm('can_manage_inventory');
  bool get canManageSuppliers => isOwnerLike && _perm('can_manage_inventory');
  bool get canManageProducts =>
      hasAssignedBranch && _perm('can_manage_products');
  bool get canViewReports => hasAssignedBranch && _perm('can_view_reports');
  bool get canViewCosts =>
      hasAssignedBranch && _perm('can_view_reports') && _perm('can_view_cost');
  bool get canManageBranches => isOwnerLike;
  bool get canManageEmployees => isOwnerLike;
  bool get canManagePermissions => isOwnerLike;
  bool get canAccessMerchantSettings => isOwnerLike;
  bool get canViewAuditLog => isOwnerLike;
  bool get canAccessSubscription => isOwnerLike;
  bool get canAccessBackupSecurity => isOwnerLike;
  bool get canAccessBranding => isOwnerLike;
  bool get canCloseShift => hasAssignedBranch;
  bool get canViewShiftArchive => isOwnerLike || canViewReports;

  bool allowsRoutePermission(String permission) {
    switch (permission) {
      case 'can_create_orders':
        return canCreateOrders;
      case 'can_manage_customers':
        return canManageCustomers;
      case 'can_manage_expenses':
        return canManageExpenses;
      case 'can_manage_inventory':
        return canManageInventory;
      case 'can_manage_products':
        return canManageProducts;
      case 'can_view_reports':
        return canViewReports;
      case 'can_view_cost':
        return canViewCosts;
      case 'can_close_shift':
        return canCloseShift;
      default:
        return hasAssignedBranch && _perm(permission);
    }
  }
}

final accessPolicyProvider = Provider<AccessPolicy>((ref) {
  return AccessPolicy(ref.watch(sessionIdentityProvider));
});

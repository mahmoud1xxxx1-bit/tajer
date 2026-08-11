import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/authentication/domain/app_user.dart';
import '../providers/effective_merchant.dart';
import 'entitlement_integration.dart';

part 'limits_service.g.dart';

class LimitsService {
  final FirebaseFirestore _firestore;

  LimitsService(this._firestore);

  Future<bool> canAddCustomer(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'customers');
  Future<bool> canAddOrder(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'orders');
  Future<bool> canAddProduct(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'products');
  Future<bool> canAddExpense(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'expenses');
  Future<bool> canAddCategory(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'categories');
  Future<bool> canAddSupplier(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'suppliers');
  Future<bool> canAddEmployee(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'employees');
  Future<bool> canAddRawMaterial(AppUser user, String branchId) async =>
      _checkQuota(user, branchId, 'raw_materials');

  Future<bool> _checkQuota(
    AppUser user,
    String branchId,
    String resourceType,
  ) async {
    final merchantId = currentEffectiveMerchantId(user);

    if (user.plan == 'banned_device' && user.isAnonymous) return false;

    if (user.plan == 'pro' ||
        user.plan == 'premium' ||
        user.email?.trim().toLowerCase() == 'love.dotk@gmail.com') {
      return true;
    }

    final isTeamMember = !isOwnerLikeRole(user.role) &&
        (user.role == 'employee' ||
            user.role == 'cashier' ||
            user.plan == 'employee' ||
            (user.merchantId != null &&
                user.merchantId!.isNotEmpty &&
                !user.isAnonymous));

    // Employees/cashiers consume the merchant workspace quota. Passing null
    // makes EntitlementIntegration resolve the merchant plan from Firestore
    // instead of interpreting the employee's own account marker as a plan.
    final planForQuota = isTeamMember ? null : user.plan;

    return EntitlementIntegration.checkQuota(
      firestore: _firestore,
      merchantId: merchantId,
      branchId: branchId,
      resourceType: resourceType,
      plan: planForQuota,
    );
  }
}

@riverpod
LimitsService limitsService(LimitsServiceRef ref) {
  return LimitsService(FirebaseFirestore.instance);
}

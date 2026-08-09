import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../branches/presentation/branch_context.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

class SessionIdentity {
  final String uid;
  final String role;
  final String effectiveMerchantId;
  final List<String> assignedBranchIds;
  final Map<String, dynamic> permissions;
  final String activeBranchId;
  final bool isOwnerLike;
  final AppUser appUser;

  const SessionIdentity({
    required this.uid,
    required this.role,
    required this.effectiveMerchantId,
    required this.assignedBranchIds,
    required this.permissions,
    required this.activeBranchId,
    required this.isOwnerLike,
    required this.appUser,
  });

  bool hasPermission(String permission) {
    if (isOwnerLike) return true;
    return permissions[permission] == true;
  }
}

final sessionIdentityProvider = Provider<SessionIdentity?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;

  final effectiveMerchantId = currentEffectiveMerchantId(appUser);
  final activeBranchId = ref.watch(selectedBranchIdProvider);
  final identity = SessionIdentity(
    uid: appUser.id,
    role: appUser.role,
    effectiveMerchantId: effectiveMerchantId,
    assignedBranchIds: List<String>.unmodifiable(appUser.assignedBranchIds),
    permissions: Map<String, dynamic>.unmodifiable(appUser.permissions),
    activeBranchId: activeBranchId,
    isOwnerLike: isOwnerLikeRole(appUser.role),
    appUser: appUser,
  );
  debugPrint(
      'SESSION_IDENTITY uid=${identity.uid} role=${identity.role} effectiveMerchantId=${identity.effectiveMerchantId} assignedBranchIds=${identity.assignedBranchIds.join(',')} activeBranchId=${identity.activeBranchId}');
  return identity;
});

final sessionIdentityReadyProvider = Provider<bool>((ref) {
  final appUserState = ref.watch(appUserProvider);
  final branchContext = ref.watch(branchContextProvider);
  final identity = ref.watch(sessionIdentityProvider);
  if (appUserState.isLoading || identity == null || !branchContext.isReady) {
    return false;
  }
  if (!identity.isOwnerLike && identity.assignedBranchIds.isEmpty) {
    return true;
  }
  return identity.activeBranchId.isNotEmpty;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/effective_merchant.dart';
import '../domain/branch.dart';

class BranchContextState {
  final String branchId;
  final bool isReady;

  const BranchContextState({required this.branchId, required this.isReady});

  const BranchContextState.loading()
      : branchId = BranchIds.main,
        isReady = false;
}

class BranchContextNotifier extends StateNotifier<BranchContextState> {
  final String merchantId;
  final List<String> allowedBranchIds;

  BranchContextNotifier(
    this.merchantId, {
    this.allowedBranchIds = const [],
  }) : super(const BranchContextState.loading()) {
    _load();
  }

  String get _prefsKey => 'selected_branch_$merchantId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = BranchContextState(
      branchId: resolveAllowedBranchId(saved, allowedBranchIds),
      isReady: true,
    );
  }

  Future<void> selectBranch(String branchId) async {
    final resolved = resolveAllowedBranchId(branchId, allowedBranchIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, resolved);
    state = BranchContextState(branchId: resolved, isReady: true);
  }

  Future<void> resetToMain() => selectBranch(BranchIds.main);
}

final branchContextProvider =
    StateNotifierProvider<BranchContextNotifier, BranchContextState>((ref) {
  final user = ref.watch(appUserProvider).value;
  final merchantId = user == null ? '' : currentEffectiveMerchantId(user);
  final allowedBranchIds =
      user == null || user.role == 'merchant' || user.role == 'admin'
          ? const <String>[]
          : effectiveEmployeeBranchIds(user.assignedBranchIds);
  return BranchContextNotifier(
    merchantId,
    allowedBranchIds: allowedBranchIds,
  );
});

final selectedBranchIdProvider = Provider<String>((ref) {
  final requested = ref.watch(branchContextProvider).branchId;
  final user = ref.watch(appUserProvider).value;
  if (user == null || user.role == 'merchant' || user.role == 'admin') {
    return requested;
  }

  final allowed = user.assignedBranchIds.isEmpty
      ? const <String>[]
      : user.assignedBranchIds;
  if (allowed.isEmpty) return '';
  return resolveAllowedBranchId(requested, allowed);
});

final employeeAllowedBranchIdsProvider = Provider<List<String>>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null || user.role == 'merchant' || user.role == 'admin') {
    return const <String>[]; // Empty means unrestricted for owner/admin.
  }
  return List<String>.unmodifiable(effectiveEmployeeBranchIds(
    user.assignedBranchIds,
  ));
});

List<String> effectiveEmployeeBranchIds(List<String> assignedBranchIds) {
  final normalized = assignedBranchIds
      .map(resolveBranchId)
      .where((branchId) => branchId.isNotEmpty)
      .toSet()
      .toList(growable: false);
  return normalized;
}

String resolveAllowedBranchId(
    String? requested, List<String> allowedBranchIds) {
  final resolved = resolveBranchId(requested);
  if (allowedBranchIds.isEmpty || allowedBranchIds.contains(resolved)) {
    return resolved;
  }
  return allowedBranchIds.first;
}

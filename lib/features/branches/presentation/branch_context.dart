import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication/data/auth_repository.dart';
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

  BranchContextNotifier(this.merchantId)
      : super(const BranchContextState.loading()) {
    _load();
  }

  String get _prefsKey => 'selected_branch_$merchantId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = BranchContextState(branchId: resolveBranchId(saved), isReady: true);
  }

  Future<void> selectBranch(String branchId) async {
    final resolved = resolveBranchId(branchId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, resolved);
    state = BranchContextState(branchId: resolved, isReady: true);
  }

  Future<void> resetToMain() => selectBranch(BranchIds.main);
}

final branchContextProvider =
    StateNotifierProvider<BranchContextNotifier, BranchContextState>((ref) {
  final user = ref.watch(appUserProvider).value;
  final merchantId = user?.merchantId ?? user?.id ?? '';
  return BranchContextNotifier(merchantId);
});

final selectedBranchIdProvider = Provider<String>((ref) {
  final requested = ref.watch(branchContextProvider).branchId;
  final user = ref.watch(appUserProvider).value;
  if (user == null || user.role == 'merchant' || user.role == 'admin') {
    return requested;
  }

  final allowed = user.assignedBranchIds.isEmpty
      ? const <String>[BranchIds.main]
      : user.assignedBranchIds;
  return allowed.contains(requested) ? requested : allowed.first;
});

final employeeAllowedBranchIdsProvider = Provider<List<String>>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null || user.role == 'merchant' || user.role == 'admin') {
    return const <String>[]; // Empty means unrestricted for owner/admin.
  }
  return user.assignedBranchIds.isEmpty
      ? const <String>[BranchIds.main]
      : List<String>.unmodifiable(user.assignedBranchIds);
});

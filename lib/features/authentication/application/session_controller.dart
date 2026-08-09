import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../branches/presentation/branch_context.dart';
import '../data/auth_repository.dart';

class SessionController {
  final Ref _ref;

  const SessionController(this._ref);

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).signOut();
    _ref.invalidate(appUserProvider);
    _ref.invalidate(branchContextProvider);
    _ref.invalidate(selectedBranchIdProvider);
    _ref.invalidate(employeeAllowedBranchIdsProvider);
    _ref.invalidate(authStateChangesProvider);
  }
}

final sessionControllerProvider = Provider<SessionController>((ref) {
  return SessionController(ref);
});

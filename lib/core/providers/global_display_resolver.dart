import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/branches/data/branch_repository.dart';

class GlobalDisplayResolver {
  final Ref _ref;

  GlobalDisplayResolver(this._ref);

  String resolveBranchName(String branchId, {required bool isAr}) {
    final branches = _ref.read(branchesStreamProvider).value;
    if (branches != null) {
      for (final b in branches) {
        if (b.id == branchId) return b.name;
      }
    }
    return isAr ? 'فرع غير متاح' : 'Unavailable branch';
  }

  String resolveActorName({
    required String? providedName,
    required bool isMerchant,
    required bool isAr,
  }) {
    if (providedName != null && providedName.trim().isNotEmpty) {
      return providedName;
    }
    if (isMerchant) {
      return isAr ? 'التاجر' : 'Merchant';
    } else {
      return isAr ? 'موظف' : 'Employee';
    }
  }
}

final globalDisplayResolverProvider = Provider<GlobalDisplayResolver>((ref) {
  return GlobalDisplayResolver(ref);
});

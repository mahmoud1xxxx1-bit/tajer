import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const AppUser._();

  const factory AppUser({
    required String id,
    String? name,
    String? phone,
    String? email,
    @Default('guest') String plan,
    required DateTime createdAt,
    @Default(true) bool isAnonymous,
    @Default('merchant') String role,
    String? merchantId,
    String? deviceId,
    @Default({}) Map<String, dynamic> permissions,
    @Default(<String>[]) List<String> assignedBranchIds,
    String? vatNumber,
    String? crNumber,
    String? nationalAddress,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  bool hasPermission(String permissionName) {
    if (role == 'merchant' || role == 'admin') return true;
    return permissions[permissionName] == true;
  }

  /// Owners/admins can operate every branch. Legacy employees created before
  /// multi-branch support are intentionally scoped to Main Branch until the
  /// merchant explicitly assigns them elsewhere.
  bool canAccessBranch(String branchId) {
    if (role == 'merchant' || role == 'admin') return true;
    final normalized = assignedBranchIds.isEmpty
        ? const <String>['main']
        : assignedBranchIds;
    return normalized.contains(branchId);
  }
}

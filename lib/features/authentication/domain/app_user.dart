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
    String? vatNumber,
    String? crNumber,
    String? nationalAddress,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  bool hasPermission(String permissionName) {
    if (role == 'merchant') return true; // Merchants have all permissions
    return permissions[permissionName] == true;
  }
}

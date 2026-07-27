import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
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
    @Default({}) Map<String, dynamic> permissions,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AppUser _$AppUserFromJson(Map<String, dynamic> json) {
  return _AppUser.fromJson(json);
}

/// @nodoc
mixin _$AppUser {
  String get id => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String get plan => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  bool get isAnonymous => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  String? get merchantId => throw _privateConstructorUsedError;
  String? get deviceId => throw _privateConstructorUsedError;
  Map<String, dynamic> get permissions => throw _privateConstructorUsedError;
  String? get vatNumber => throw _privateConstructorUsedError;
  String? get crNumber => throw _privateConstructorUsedError;
  String? get nationalAddress => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AppUserCopyWith<AppUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserCopyWith<$Res> {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) then) =
      _$AppUserCopyWithImpl<$Res, AppUser>;
  @useResult
  $Res call(
      {String id,
      String? name,
      String? phone,
      String? email,
      String plan,
      DateTime createdAt,
      bool isAnonymous,
      String role,
      String? merchantId,
      String? deviceId,
      Map<String, dynamic> permissions,
      String? vatNumber,
      String? crNumber,
      String? nationalAddress});
}

/// @nodoc
class _$AppUserCopyWithImpl<$Res, $Val extends AppUser>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? phone = freezed,
    Object? email = freezed,
    Object? plan = null,
    Object? createdAt = null,
    Object? isAnonymous = null,
    Object? role = null,
    Object? merchantId = freezed,
    Object? deviceId = freezed,
    Object? permissions = null,
    Object? vatNumber = freezed,
    Object? crNumber = freezed,
    Object? nationalAddress = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      phone: freezed == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      plan: null == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isAnonymous: null == isAnonymous
          ? _value.isAnonymous
          : isAnonymous // ignore: cast_nullable_to_non_nullable
              as bool,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: freezed == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceId: freezed == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String?,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      vatNumber: freezed == vatNumber
          ? _value.vatNumber
          : vatNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      crNumber: freezed == crNumber
          ? _value.crNumber
          : crNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      nationalAddress: freezed == nationalAddress
          ? _value.nationalAddress
          : nationalAddress // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppUserImplCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$$AppUserImplCopyWith(
          _$AppUserImpl value, $Res Function(_$AppUserImpl) then) =
      __$$AppUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String? name,
      String? phone,
      String? email,
      String plan,
      DateTime createdAt,
      bool isAnonymous,
      String role,
      String? merchantId,
      String? deviceId,
      Map<String, dynamic> permissions,
      String? vatNumber,
      String? crNumber,
      String? nationalAddress});
}

/// @nodoc
class __$$AppUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$AppUserImpl>
    implements _$$AppUserImplCopyWith<$Res> {
  __$$AppUserImplCopyWithImpl(
      _$AppUserImpl _value, $Res Function(_$AppUserImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? phone = freezed,
    Object? email = freezed,
    Object? plan = null,
    Object? createdAt = null,
    Object? isAnonymous = null,
    Object? role = null,
    Object? merchantId = freezed,
    Object? deviceId = freezed,
    Object? permissions = null,
    Object? vatNumber = freezed,
    Object? crNumber = freezed,
    Object? nationalAddress = freezed,
  }) {
    return _then(_$AppUserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      phone: freezed == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      plan: null == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isAnonymous: null == isAnonymous
          ? _value.isAnonymous
          : isAnonymous // ignore: cast_nullable_to_non_nullable
              as bool,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: freezed == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceId: freezed == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String?,
      permissions: null == permissions
          ? _value._permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      vatNumber: freezed == vatNumber
          ? _value.vatNumber
          : vatNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      crNumber: freezed == crNumber
          ? _value.crNumber
          : crNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      nationalAddress: freezed == nationalAddress
          ? _value.nationalAddress
          : nationalAddress // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppUserImpl extends _AppUser {
  const _$AppUserImpl(
      {required this.id,
      this.name,
      this.phone,
      this.email,
      this.plan = 'guest',
      required this.createdAt,
      this.isAnonymous = true,
      this.role = 'merchant',
      this.merchantId,
      this.deviceId,
      final Map<String, dynamic> permissions = const {},
      this.vatNumber,
      this.crNumber,
      this.nationalAddress})
      : _permissions = permissions,
        super._();

  factory _$AppUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUserImplFromJson(json);

  @override
  final String id;
  @override
  final String? name;
  @override
  final String? phone;
  @override
  final String? email;
  @override
  @JsonKey()
  final String plan;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final bool isAnonymous;
  @override
  @JsonKey()
  final String role;
  @override
  final String? merchantId;
  @override
  final String? deviceId;
  final Map<String, dynamic> _permissions;
  @override
  @JsonKey()
  Map<String, dynamic> get permissions {
    if (_permissions is EqualUnmodifiableMapView) return _permissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_permissions);
  }

  @override
  final String? vatNumber;
  @override
  final String? crNumber;
  @override
  final String? nationalAddress;

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, phone: $phone, email: $email, plan: $plan, createdAt: $createdAt, isAnonymous: $isAnonymous, role: $role, merchantId: $merchantId, deviceId: $deviceId, permissions: $permissions, vatNumber: $vatNumber, crNumber: $crNumber, nationalAddress: $nationalAddress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.plan, plan) || other.plan == plan) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isAnonymous, isAnonymous) ||
                other.isAnonymous == isAnonymous) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            const DeepCollectionEquality()
                .equals(other._permissions, _permissions) &&
            (identical(other.vatNumber, vatNumber) ||
                other.vatNumber == vatNumber) &&
            (identical(other.crNumber, crNumber) ||
                other.crNumber == crNumber) &&
            (identical(other.nationalAddress, nationalAddress) ||
                other.nationalAddress == nationalAddress));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      phone,
      email,
      plan,
      createdAt,
      isAnonymous,
      role,
      merchantId,
      deviceId,
      const DeepCollectionEquality().hash(_permissions),
      vatNumber,
      crNumber,
      nationalAddress);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      __$$AppUserImplCopyWithImpl<_$AppUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppUserImplToJson(
      this,
    );
  }
}

abstract class _AppUser extends AppUser {
  const factory _AppUser(
      {required final String id,
      final String? name,
      final String? phone,
      final String? email,
      final String plan,
      required final DateTime createdAt,
      final bool isAnonymous,
      final String role,
      final String? merchantId,
      final String? deviceId,
      final Map<String, dynamic> permissions,
      final String? vatNumber,
      final String? crNumber,
      final String? nationalAddress}) = _$AppUserImpl;
  const _AppUser._() : super._();

  factory _AppUser.fromJson(Map<String, dynamic> json) = _$AppUserImpl.fromJson;

  @override
  String get id;
  @override
  String? get name;
  @override
  String? get phone;
  @override
  String? get email;
  @override
  String get plan;
  @override
  DateTime get createdAt;
  @override
  bool get isAnonymous;
  @override
  String get role;
  @override
  String? get merchantId;
  @override
  String? get deviceId;
  @override
  Map<String, dynamic> get permissions;
  @override
  String? get vatNumber;
  @override
  String? get crNumber;
  @override
  String? get nationalAddress;
  @override
  @JsonKey(ignore: true)
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

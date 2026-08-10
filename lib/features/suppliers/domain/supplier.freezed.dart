// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supplier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Supplier _$SupplierFromJson(Map<String, dynamic> json) {
  return _Supplier.fromJson(json);
}

/// @nodoc
mixin _$Supplier {
  String get id => throw _privateConstructorUsedError;
  String get merchantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  double get totalDebt =>
      throw _privateConstructorUsedError; // Amount the merchant owes the supplier
  bool get isActive => throw _privateConstructorUsedError;
  List<String> get associatedBranchIds => throw _privateConstructorUsedError;
  Map<String, double> get branchDebts => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SupplierCopyWith<Supplier> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupplierCopyWith<$Res> {
  factory $SupplierCopyWith(Supplier value, $Res Function(Supplier) then) =
      _$SupplierCopyWithImpl<$Res, Supplier>;
  @useResult
  $Res call(
      {String id,
      String merchantId,
      String name,
      String? phone,
      String? address,
      double totalDebt,
      bool isActive,
      List<String> associatedBranchIds,
      Map<String, double> branchDebts,
      @TimestampConverter() DateTime createdAt});
}

/// @nodoc
class _$SupplierCopyWithImpl<$Res, $Val extends Supplier>
    implements $SupplierCopyWith<$Res> {
  _$SupplierCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? name = null,
    Object? phone = freezed,
    Object? address = freezed,
    Object? totalDebt = null,
    Object? isActive = null,
    Object? associatedBranchIds = null,
    Object? branchDebts = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: freezed == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      totalDebt: null == totalDebt
          ? _value.totalDebt
          : totalDebt // ignore: cast_nullable_to_non_nullable
              as double,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      associatedBranchIds: null == associatedBranchIds
          ? _value.associatedBranchIds
          : associatedBranchIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      branchDebts: null == branchDebts
          ? _value.branchDebts
          : branchDebts // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SupplierImplCopyWith<$Res>
    implements $SupplierCopyWith<$Res> {
  factory _$$SupplierImplCopyWith(
          _$SupplierImpl value, $Res Function(_$SupplierImpl) then) =
      __$$SupplierImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String merchantId,
      String name,
      String? phone,
      String? address,
      double totalDebt,
      bool isActive,
      List<String> associatedBranchIds,
      Map<String, double> branchDebts,
      @TimestampConverter() DateTime createdAt});
}

/// @nodoc
class __$$SupplierImplCopyWithImpl<$Res>
    extends _$SupplierCopyWithImpl<$Res, _$SupplierImpl>
    implements _$$SupplierImplCopyWith<$Res> {
  __$$SupplierImplCopyWithImpl(
      _$SupplierImpl _value, $Res Function(_$SupplierImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? name = null,
    Object? phone = freezed,
    Object? address = freezed,
    Object? totalDebt = null,
    Object? isActive = null,
    Object? associatedBranchIds = null,
    Object? branchDebts = null,
    Object? createdAt = null,
  }) {
    return _then(_$SupplierImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: freezed == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      totalDebt: null == totalDebt
          ? _value.totalDebt
          : totalDebt // ignore: cast_nullable_to_non_nullable
              as double,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      associatedBranchIds: null == associatedBranchIds
          ? _value._associatedBranchIds
          : associatedBranchIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      branchDebts: null == branchDebts
          ? _value._branchDebts
          : branchDebts // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SupplierImpl implements _Supplier {
  const _$SupplierImpl(
      {required this.id,
      required this.merchantId,
      required this.name,
      this.phone,
      this.address,
      this.totalDebt = 0.0,
      this.isActive = true,
      final List<String> associatedBranchIds = const [],
      final Map<String, double> branchDebts = const {},
      @TimestampConverter() required this.createdAt})
      : _associatedBranchIds = associatedBranchIds,
        _branchDebts = branchDebts;

  factory _$SupplierImpl.fromJson(Map<String, dynamic> json) =>
      _$$SupplierImplFromJson(json);

  @override
  final String id;
  @override
  final String merchantId;
  @override
  final String name;
  @override
  final String? phone;
  @override
  final String? address;
  @override
  @JsonKey()
  final double totalDebt;
// Amount the merchant owes the supplier
  @override
  @JsonKey()
  final bool isActive;
  final List<String> _associatedBranchIds;
  @override
  @JsonKey()
  List<String> get associatedBranchIds {
    if (_associatedBranchIds is EqualUnmodifiableListView)
      return _associatedBranchIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_associatedBranchIds);
  }

  final Map<String, double> _branchDebts;
  @override
  @JsonKey()
  Map<String, double> get branchDebts {
    if (_branchDebts is EqualUnmodifiableMapView) return _branchDebts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_branchDebts);
  }

  @override
  @TimestampConverter()
  final DateTime createdAt;

  @override
  String toString() {
    return 'Supplier(id: $id, merchantId: $merchantId, name: $name, phone: $phone, address: $address, totalDebt: $totalDebt, isActive: $isActive, associatedBranchIds: $associatedBranchIds, branchDebts: $branchDebts, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.totalDebt, totalDebt) ||
                other.totalDebt == totalDebt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            const DeepCollectionEquality()
                .equals(other._associatedBranchIds, _associatedBranchIds) &&
            const DeepCollectionEquality()
                .equals(other._branchDebts, _branchDebts) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      merchantId,
      name,
      phone,
      address,
      totalDebt,
      isActive,
      const DeepCollectionEquality().hash(_associatedBranchIds),
      const DeepCollectionEquality().hash(_branchDebts),
      createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierImplCopyWith<_$SupplierImpl> get copyWith =>
      __$$SupplierImplCopyWithImpl<_$SupplierImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SupplierImplToJson(
      this,
    );
  }
}

abstract class _Supplier implements Supplier {
  const factory _Supplier(
          {required final String id,
          required final String merchantId,
          required final String name,
          final String? phone,
          final String? address,
          final double totalDebt,
          final bool isActive,
          final List<String> associatedBranchIds,
          final Map<String, double> branchDebts,
          @TimestampConverter() required final DateTime createdAt}) =
      _$SupplierImpl;

  factory _Supplier.fromJson(Map<String, dynamic> json) =
      _$SupplierImpl.fromJson;

  @override
  String get id;
  @override
  String get merchantId;
  @override
  String get name;
  @override
  String? get phone;
  @override
  String? get address;
  @override
  double get totalDebt;
  @override // Amount the merchant owes the supplier
  bool get isActive;
  @override
  List<String> get associatedBranchIds;
  @override
  Map<String, double> get branchDebts;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$SupplierImplCopyWith<_$SupplierImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

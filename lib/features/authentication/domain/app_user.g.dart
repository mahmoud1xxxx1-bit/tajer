// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      plan: json['plan'] as String? ?? 'guest',
      createdAt: DateTime.parse(json['createdAt'] as String),
      isAnonymous: json['isAnonymous'] as bool? ?? true,
      role: json['role'] as String? ?? 'merchant',
      merchantId: json['merchantId'] as String?,
      deviceId: json['deviceId'] as String?,
      permissions: json['permissions'] as Map<String, dynamic>? ?? const {},
      vatNumber: json['vatNumber'] as String?,
      crNumber: json['crNumber'] as String?,
      nationalAddress: json['nationalAddress'] as String?,
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'email': instance.email,
      'plan': instance.plan,
      'createdAt': instance.createdAt.toIso8601String(),
      'isAnonymous': instance.isAnonymous,
      'role': instance.role,
      'merchantId': instance.merchantId,
      'deviceId': instance.deviceId,
      'permissions': instance.permissions,
      'vatNumber': instance.vatNumber,
      'crNumber': instance.crNumber,
      'nationalAddress': instance.nationalAddress,
    };

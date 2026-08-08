import 'package:cloud_firestore/cloud_firestore.dart';

/// Stable branch identifiers used by Tajer.
///
/// Legacy records created before multi-branch support do not contain a
/// `branchId`. They always belong to [main] for backward compatibility.
abstract final class BranchIds {
  static const String main = 'main';
}

String resolveBranchId(dynamic value) {
  final branchId = value?.toString().trim();
  return branchId == null || branchId.isEmpty ? BranchIds.main : branchId;
}

class Branch {
  final String id;
  final String merchantId;
  final String name;
  final bool isMain;
  final bool isActive;
  final String? phone;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Branch({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.isMain,
    required this.isActive,
    this.phone,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Branch.main({
    required String merchantId,
    required String name,
  }) {
    final now = DateTime.now();
    return Branch(
      id: BranchIds.main,
      merchantId: merchantId,
      name: name,
      isMain: true,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Branch.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return Branch(
      id: resolveBranchId(json['id']),
      merchantId: json['merchantId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isMain: json['isMain'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchantId': merchantId,
        'name': name,
        'isMain': isMain,
        'isActive': isActive,
        'phone': phone,
        'address': address,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Branch copyWith({
    String? id,
    String? merchantId,
    String? name,
    bool? isMain,
    bool? isActive,
    String? phone,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Branch(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      isMain: isMain ?? this.isMain,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

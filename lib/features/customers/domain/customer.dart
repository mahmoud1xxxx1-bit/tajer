import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class Customer {
  final String id;
  final String merchantId;
  final String branchId;
  final String name;
  final String phone;
  final double totalPurchases;
  final int orderCount;
  final double totalDebt;
  final DateTime? lastPurchaseDate;
  final DateTime createdAt;
  final String? creatorName;
  final String? folderName;
  final bool isActive;

  const Customer({
    required this.id,
    required this.merchantId,
    this.branchId = 'main',
    required this.name,
    required this.phone,
    this.totalPurchases = 0.0,
    this.orderCount = 0,
    this.totalDebt = 0.0,
    this.lastPurchaseDate,
    required this.createdAt,
    this.creatorName,
    this.folderName,
    this.isActive = true,
  });

  Customer copyWith({
    String? id,
    String? merchantId,
    String? branchId,
    String? name,
    String? phone,
    double? totalPurchases,
    int? orderCount,
    double? totalDebt,
    DateTime? lastPurchaseDate,
    DateTime? createdAt,
    String? creatorName,
    String? folderName,
    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      orderCount: orderCount ?? this.orderCount,
      totalDebt: totalDebt ?? this.totalDebt,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      createdAt: createdAt ?? this.createdAt,
      creatorName: creatorName ?? this.creatorName,
      folderName: folderName ?? this.folderName,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String? ?? '',
      merchantId: json['merchantId'] as String? ?? '',
      branchId: json['branchId']?.toString().trim().isEmpty == false
          ? json['branchId'].toString()
          : 'main',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0.0,
      lastPurchaseDate: json['lastPurchaseDate'] != null
          ? safeParseDate(json['lastPurchaseDate'])
          : null,
      createdAt: json['createdAt'] != null
          ? safeParseDate(json['createdAt'])
          : DateTime.now(),
      creatorName: json['creatorName'] as String?,
      folderName: json['folderName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'branchId': branchId,
      'name': name,
      'phone': phone,
      'totalPurchases': totalPurchases,
      'orderCount': orderCount,
      'totalDebt': totalDebt,
      'lastPurchaseDate': lastPurchaseDate != null
          ? Timestamp.fromDate(lastPurchaseDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'creatorName': creatorName,
      'folderName': folderName,
      'isActive': isActive,
    };
  }
}

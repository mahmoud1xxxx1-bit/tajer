import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String merchantId;
  final String name;
  final String phone;
  final double totalPurchases;
  final int orderCount;
  final double totalDebt;
  final DateTime? lastPurchaseDate;
  final DateTime createdAt;
  final String? creatorName;

  const Customer({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.phone,
    this.totalPurchases = 0.0,
    this.orderCount = 0,
    this.totalDebt = 0.0,
    this.lastPurchaseDate,
    required this.createdAt,
    this.creatorName,
  });

  Customer copyWith({
    String? id,
    String? merchantId,
    String? name,
    String? phone,
    double? totalPurchases,
    int? orderCount,
    double? totalDebt,
    DateTime? lastPurchaseDate,
    DateTime? createdAt,
    String? creatorName,
  }) {
    return Customer(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      orderCount: orderCount ?? this.orderCount,
      totalDebt: totalDebt ?? this.totalDebt,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      createdAt: createdAt ?? this.createdAt,
      creatorName: creatorName ?? this.creatorName,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String? ?? '',
      merchantId: json['merchantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0.0,
      lastPurchaseDate: json['lastPurchaseDate'] != null && json['lastPurchaseDate'] is Timestamp
          ? (json['lastPurchaseDate'] as Timestamp).toDate()
          : null,
      createdAt: json['createdAt'] != null && json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      creatorName: json['creatorName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'name': name,
      'phone': phone,
      'totalPurchases': totalPurchases,
      'orderCount': orderCount,
      'totalDebt': totalDebt,
      'lastPurchaseDate': lastPurchaseDate != null ? Timestamp.fromDate(lastPurchaseDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'creatorName': creatorName,
    };
  }
}

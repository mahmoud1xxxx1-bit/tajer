import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierTransaction {
  final String id;
  final String supplierId;
  final String merchantId;
  final double amount;
  final String type; // 'debt_addition', 'payment'
  final String description;
  final DateTime date;
  final DateTime createdAt;

  SupplierTransaction({
    required this.id,
    required this.supplierId,
    required this.merchantId,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    required this.createdAt,
  });

  factory SupplierTransaction.fromJson(Map<String, dynamic> json) {
    return SupplierTransaction(
      id: json['id'] ?? '',
      supplierId: json['supplierId'] ?? '',
      merchantId: json['merchantId'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: json['type'] ?? 'payment',
      description: json['description'] ?? '',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierId': supplierId,
      'merchantId': merchantId,
      'amount': amount,
      'type': type,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

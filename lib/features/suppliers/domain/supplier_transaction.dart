import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class SupplierTransaction {
  final String id;
  final String supplierId;
  final String merchantId;
  final double amount;
  final String type; // 'debt_addition', 'payment'
  final String? paymentMethod; // 'cash', 'network'
  final String description;
  final DateTime date;
  final DateTime createdAt;

  SupplierTransaction({
    required this.id,
    required this.supplierId,
    required this.merchantId,
    required this.amount,
    required this.type,
    this.paymentMethod = 'cash',
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
      paymentMethod: json['paymentMethod'] ?? 'cash',
      description: json['description'] ?? '',
      date: safeParseDate(json['date']),
      createdAt: safeParseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierId': supplierId,
      'merchantId': merchantId,
      'amount': amount,
      'type': type,
      'paymentMethod': paymentMethod,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

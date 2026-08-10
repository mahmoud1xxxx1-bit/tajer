import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class SupplierTransaction {
  final String id;
  final String supplierId;
  final String merchantId;
  final String branchId;
  final String? expenseId;
  final double amount;
  final String type; // 'debt_addition', 'payment', 'purchase'
  final String? paymentMethod; // 'cash', 'network'
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final bool isCancelled;
  final String? purchaseInvoiceId;

  SupplierTransaction({
    required this.id,
    required this.supplierId,
    required this.merchantId,
    this.branchId = 'main',
    this.expenseId,
    required this.amount,
    required this.type,
    this.paymentMethod = 'cash',
    required this.description,
    required this.date,
    required this.createdAt,
    this.isCancelled = false,
    this.purchaseInvoiceId,
  });

  factory SupplierTransaction.fromJson(Map<String, dynamic> json) {
    return SupplierTransaction(
      id: json['id'] ?? '',
      supplierId: json['supplierId'] ?? '',
      merchantId: json['merchantId'] ?? '',
      branchId: json['branchId']?.toString() ?? 'main',
      expenseId: json['expenseId']?.toString(),
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: json['type'] ?? 'payment',
      paymentMethod: json['paymentMethod'] ?? 'cash',
      description: json['description'] ?? '',
      date: safeParseDate(json['date']),
      createdAt: safeParseDate(json['createdAt']),
      isCancelled: json['isCancelled'] as bool? ?? false,
      purchaseInvoiceId: json['purchaseInvoiceId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierId': supplierId,
      'merchantId': merchantId,
      'branchId': branchId,
      'expenseId': expenseId,
      'amount': amount,
      'type': type,
      'paymentMethod': paymentMethod,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'isCancelled': isCancelled,
      if (purchaseInvoiceId != null) 'purchaseInvoiceId': purchaseInvoiceId,
    };
  }

  SupplierTransaction copyWith({
    String? id,
    String? supplierId,
    String? merchantId,
    String? branchId,
    String? expenseId,
    double? amount,
    String? type,
    String? paymentMethod,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    bool? isCancelled,
    String? purchaseInvoiceId,
  }) {
    return SupplierTransaction(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      merchantId: merchantId ?? this.merchantId,
      branchId: branchId ?? this.branchId,
      expenseId: expenseId ?? this.expenseId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      isCancelled: isCancelled ?? this.isCancelled,
      purchaseInvoiceId: purchaseInvoiceId ?? this.purchaseInvoiceId,
    );
  }
}

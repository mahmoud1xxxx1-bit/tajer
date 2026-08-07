import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/domain/product.dart'; // For TimestampConverter

class Expense {
  final String id;
  final String merchantId;
  final String title;
  final double amount;
  final String? category;
  final String? notes;
  final String? creatorId;
  final String? creatorName;
  final bool isSupplierPayment;
  final String paymentMethod; // 'cash' or 'network'
  final DateTime date;
  final DateTime createdAt;
  final bool isFromShiftDrawer;
  final bool isCancelled;

  const Expense({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.amount,
    this.category,
    this.notes,
    this.creatorId,
    this.creatorName,
    this.isSupplierPayment = false,
    this.paymentMethod = 'cash',
    required this.date,
    required this.createdAt,
    this.isFromShiftDrawer = true, // Default to true for backward compatibility
    this.isCancelled = false,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String? ?? '',
      merchantId: json['merchantId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      notes: json['notes'] as String?,
      creatorId: json['creatorId'] as String?,
      creatorName: json['creatorName'] as String?,
      isSupplierPayment: json['isSupplierPayment'] as bool? ?? false,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      date: const TimestampConverter().fromJson(json['date']),
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      isFromShiftDrawer: json['isFromShiftDrawer'] as bool? ?? true,
      isCancelled: json['isCancelled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'title': title,
      'amount': amount,
      'category': category,
      'notes': notes,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'isSupplierPayment': isSupplierPayment,
      'paymentMethod': paymentMethod,
      'date': const TimestampConverter().toJson(date),
      'createdAt': const TimestampConverter().toJson(createdAt),
      'isFromShiftDrawer': isFromShiftDrawer,
      'isCancelled': isCancelled,
    };
  }

  Expense copyWith({
    String? id,
    String? merchantId,
    String? title,
    double? amount,
    String? category,
    String? notes,
    String? creatorId,
    String? creatorName,
    bool? isSupplierPayment,
    String? paymentMethod,
    DateTime? date,
    DateTime? createdAt,
    bool? isFromShiftDrawer,
    bool? isCancelled,
  }) {
    return Expense(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      isSupplierPayment: isSupplierPayment ?? this.isSupplierPayment,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      isFromShiftDrawer: isFromShiftDrawer ?? this.isFromShiftDrawer,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

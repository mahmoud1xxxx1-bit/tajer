import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';
import '../../products/domain/product.dart'; // For TimestampConverter
import 'cart_item.dart';

class AppOrder {
  final String id;
  final String merchantId;
  final String customerId;
  final String customerName;
  final List<CartItem> items;
  final double total;
  final String status;
  final double paidAmount;
  final bool isCredit;
  final String? notes;
  final String? creatorId;
  final String? creatorName;
  final String? paymentMethod;
  final DateTime? scheduledDate;
  final int? queueNumber;
  final double? tenderedAmount;
  final double? changeAmount;
  final double? splitCashAmount;
  final double? splitNetworkAmount;
  final DateTime createdAt;

  const AppOrder({
    required this.id,
    required this.merchantId,
    required this.customerId,
    required this.customerName,
    this.items = const [],
    required this.total,
    this.status = 'pending',
    this.paidAmount = 0.0,
    this.isCredit = false,
    this.notes,
    this.creatorId,
    this.creatorName,
    this.paymentMethod,
    this.scheduledDate,
    this.queueNumber,
    this.tenderedAmount,
    this.changeAmount,
    this.splitCashAmount,
    this.splitNetworkAmount,
    required this.createdAt,
  });

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    return AppOrder(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      isCredit: json['isCredit'] as bool? ?? false,
      notes: json['notes'] as String?,
      creatorId: json['creatorId'] as String?,
      creatorName: json['creatorName'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      scheduledDate: safeParseNullableDate(json['scheduledDate']),
      queueNumber: json['queueNumber'] as int?,
      tenderedAmount: (json['tenderedAmount'] as num?)?.toDouble(),
      changeAmount: (json['changeAmount'] as num?)?.toDouble(),
      splitCashAmount: (json['splitCashAmount'] as num?)?.toDouble(),
      splitNetworkAmount: (json['splitNetworkAmount'] as num?)?.toDouble(),
      createdAt: safeParseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((e) => e.toJson()).toList(),
      'total': total,
      'status': status,
      'paidAmount': paidAmount,
      'isCredit': isCredit,
      'notes': notes,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'paymentMethod': paymentMethod ?? 'cash',
      'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'queueNumber': queueNumber,
      'tenderedAmount': tenderedAmount,
      'changeAmount': changeAmount,
      'splitCashAmount': splitCashAmount,
      'splitNetworkAmount': splitNetworkAmount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppOrder copyWith({
    String? id,
    String? merchantId,
    String? customerId,
    String? customerName,
    List<CartItem>? items,
    double? total,
    String? status,
    double? paidAmount,
    bool? isCredit,
    String? notes,
    String? creatorId,
    String? creatorName,
    String? paymentMethod,
    DateTime? scheduledDate,
    int? queueNumber,
    double? tenderedAmount,
    double? changeAmount,
    double? splitCashAmount,
    double? splitNetworkAmount,
    DateTime? createdAt,
  }) {
    return AppOrder(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      total: total ?? this.total,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      isCredit: isCredit ?? this.isCredit,
      notes: notes ?? this.notes,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      queueNumber: queueNumber ?? this.queueNumber,
      tenderedAmount: tenderedAmount ?? this.tenderedAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      splitCashAmount: splitCashAmount ?? this.splitCashAmount,
      splitNetworkAmount: splitNetworkAmount ?? this.splitNetworkAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

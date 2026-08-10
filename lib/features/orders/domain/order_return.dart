import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';
import 'cart_item.dart';

class OrderReturn {
  final String id;
  final String merchantId;
  final String branchId;
  final String originalOrderId;
  final List<CartItem> returnedItems;
  final double returnedTotal;
  final double returnedTax;
  final String? shiftId;
  final String? employeeId;
  final String paymentMethod;
  final String? reason;
  final DateTime createdAt;

  const OrderReturn({
    required this.id,
    required this.merchantId,
    required this.branchId,
    required this.originalOrderId,
    required this.returnedItems,
    required this.returnedTotal,
    required this.returnedTax,
    this.shiftId,
    this.employeeId,
    required this.paymentMethod,
    this.reason,
    required this.createdAt,
  });

  factory OrderReturn.fromJson(Map<String, dynamic> json) {
    return OrderReturn(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      branchId: json['branchId'] as String? ?? 'main',
      originalOrderId: json['originalOrderId'] as String,
      returnedItems: (json['returnedItems'] as List<dynamic>?)
              ?.map(
                  (e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      returnedTotal: (json['returnedTotal'] as num).toDouble(),
      returnedTax: (json['returnedTax'] as num?)?.toDouble() ?? 0.0,
      shiftId: json['shiftId'] as String?,
      employeeId: json['employeeId'] as String?,
      paymentMethod: json['paymentMethod'] as String,
      reason: json['reason'] as String?,
      createdAt: safeParseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'branchId': branchId,
      'originalOrderId': originalOrderId,
      'returnedItems': returnedItems.map((e) => e.toJson()).toList(),
      'returnedTotal': returnedTotal,
      'returnedTax': returnedTax,
      'shiftId': shiftId,
      'employeeId': employeeId,
      'paymentMethod': paymentMethod,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

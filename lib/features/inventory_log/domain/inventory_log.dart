import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class InventoryLog {
  final String id;
  final String merchantId;
  final String productId;
  final String productName;
  final double changeQuantity;
  final double previousQuantity;
  final double newQuantity;
  final String reason;
  final String? userEmail;
  final String? userName;
  final String? itemType; // 'product' or 'raw_material'
  final bool isReverted;
  final DateTime date;

  const InventoryLog({
    required this.id,
    required this.merchantId,
    required this.productId,
    required this.productName,
    required this.changeQuantity,
    required this.previousQuantity,
    required this.newQuantity,
    required this.reason,
    this.userEmail,
    this.userName,
    this.itemType,
    this.isReverted = false,
    required this.date,
  });

  factory InventoryLog.fromJson(Map<String, dynamic> json) {
    return InventoryLog(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      changeQuantity: (json['changeQuantity'] as num).toDouble(),
      previousQuantity: (json['previousQuantity'] as num).toDouble(),
      newQuantity: (json['newQuantity'] as num).toDouble(),
      reason: json['reason'] as String,
      userEmail: json['userEmail'] as String?,
      userName: json['userName'] as String?,
      itemType: json['itemType'] as String?,
      isReverted: json['isReverted'] as bool? ?? false,
      date: safeParseDate(json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'productId': productId,
      'productName': productName,
      'changeQuantity': changeQuantity,
      'previousQuantity': previousQuantity,
      'newQuantity': newQuantity,
      'reason': reason,
      'userEmail': userEmail,
      'userName': userName,
      'itemType': itemType,
      'isReverted': isReverted,
      'date': Timestamp.fromDate(date),
    };
  }

  InventoryLog copyWith({
    String? id,
    String? merchantId,
    String? productId,
    String? productName,
    double? changeQuantity,
    double? previousQuantity,
    double? newQuantity,
    String? reason,
    String? userEmail,
    String? userName,
    String? itemType,
    bool? isReverted,
    DateTime? date,
  }) {
    return InventoryLog(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      changeQuantity: changeQuantity ?? this.changeQuantity,
      previousQuantity: previousQuantity ?? this.previousQuantity,
      newQuantity: newQuantity ?? this.newQuantity,
      reason: reason ?? this.reason,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      itemType: itemType ?? this.itemType,
      isReverted: isReverted ?? this.isReverted,
      date: date ?? this.date,
    );
  }
}

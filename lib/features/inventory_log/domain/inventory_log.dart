import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/domain/product.dart'; // For TimestampConverter

part 'inventory_log.freezed.dart';
part 'inventory_log.g.dart';

@freezed
class InventoryLog with _$InventoryLog {
  const factory InventoryLog({
    required String id,
    required String merchantId,
    required String productId,
    required String productName,
    required int changeQuantity,
    required int previousQuantity,
    required int newQuantity,
    required String reason, // e.g. "Sale", "Manual Adjustment", "Restock"
    String? userEmail, // Who made the change
    @TimestampConverter() required DateTime date,
  }) = _InventoryLog;

  factory InventoryLog.fromJson(Map<String, dynamic> json) => _$InventoryLogFromJson(json);
}

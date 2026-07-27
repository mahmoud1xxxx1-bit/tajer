import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/domain/product.dart'; // For TimestampConverter

part 'order.freezed.dart';
part 'order.g.dart';

@freezed
class AppOrder with _$AppOrder {
  const factory AppOrder({
    required String id,
    required String merchantId,
    required String customerId,
    required String customerName,
    required String productId,
    required String productName,
    required int quantity,
    required double price,
    required double total,
    String? notes,
    @TimestampConverter() required DateTime createdAt,
  }) = _AppOrder;

  factory AppOrder.fromJson(Map<String, dynamic> json) => _$AppOrderFromJson(json);
}

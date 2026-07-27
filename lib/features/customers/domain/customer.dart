import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/domain/product.dart'; // For TimestampConverter

part 'customer.freezed.dart';
part 'customer.g.dart';

@freezed
class Customer with _$Customer {
  const factory Customer({
    required String id,
    required String merchantId,
    required String name,
    required String phone,
    @Default(0.0) double totalPurchases,
    @Default(0) int orderCount,
    @Default(0.0) double totalDebt,
    @NullableTimestampConverter() DateTime? lastPurchaseDate,
    @TimestampConverter() required DateTime createdAt,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
}

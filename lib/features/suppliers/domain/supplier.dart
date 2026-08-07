import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/domain/product.dart'; // For TimestampConverter

part 'supplier.freezed.dart';
part 'supplier.g.dart';

@freezed
class Supplier with _$Supplier {
  const factory Supplier({
    required String id,
    required String merchantId,
    required String name,
    String? phone,
    String? address,
    @Default(0.0) double totalDebt, // Amount the merchant owes the supplier
    @Default(true) bool isActive,
    @TimestampConverter() required DateTime createdAt,
  }) = _Supplier;

  factory Supplier.fromJson(Map<String, dynamic> json) => _$SupplierFromJson(json);
}

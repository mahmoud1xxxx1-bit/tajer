import 'package:freezed_annotation/freezed_annotation.dart';
import '../../products/domain/product.dart'; // For TimestampConverter

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String merchantId,
    required String name,
    @TimestampConverter() required DateTime createdAt,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
}

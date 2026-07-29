import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/domain/product.dart'; // For TimestampConverter

part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String merchantId,
    required String title,
    required double amount,
    String? category,
    String? notes,
    String? creatorId,
    String? creatorName,
    @TimestampConverter() required DateTime date,
    @TimestampConverter() required DateTime createdAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
}

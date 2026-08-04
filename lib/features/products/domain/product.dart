import 'package:cloud_firestore/cloud_firestore.dart';
import 'raw_material.dart';

class Product {
  final String id;
  final String merchantId;
  final String name;
  final String? categoryId;
  final String? barcode;
  final double price;
  final int quantity;
  final List<String> modifiers;
  final List<RecipeItem> recipe;
  final bool? isTaxInclusive;
  final double? taxPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.merchantId,
    required this.name,
    this.categoryId,
    this.barcode,
    required this.price,
    required this.quantity,
    this.modifiers = const [],
    this.recipe = const [],
    this.isTaxInclusive,
    this.taxPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String?,
      barcode: json['barcode'] as String?,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      modifiers: (json['modifiers'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      recipe: (json['recipe'] as List<dynamic>?)?.map((e) => RecipeItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      isTaxInclusive: json['isTaxInclusive'] as bool?,
      taxPercentage: json['taxPercentage'] != null ? (json['taxPercentage'] as num).toDouble() : null,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'name': name,
      'categoryId': categoryId,
      'barcode': barcode,
      'price': price,
      'quantity': quantity,
      'modifiers': modifiers,
      'recipe': recipe.map((e) => e.toJson()).toList(),
      'isTaxInclusive': isTaxInclusive,
      'taxPercentage': taxPercentage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Product copyWith({
    String? id,
    String? merchantId,
    String? name,
    String? categoryId,
    String? barcode,
    double? price,
    int? quantity,
    List<String>? modifiers,
    List<RecipeItem>? recipe,
    bool? isTaxInclusive,
    double? taxPercentage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      recipe: recipe ?? this.recipe,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

class TimestampConverter {
  const TimestampConverter();

  DateTime fromJson(dynamic json) {
    if (json is Timestamp) return json.toDate();
    if (json is String) return DateTime.parse(json);
    return DateTime.now();
  }

  dynamic toJson(DateTime object) {
    return Timestamp.fromDate(object);
  }
}

class NullableTimestampConverter {
  const NullableTimestampConverter();

  DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is String) return DateTime.parse(json);
    return DateTime.now();
  }

  dynamic toJson(DateTime? object) {
    if (object == null) return null;
    return Timestamp.fromDate(object);
  }
}

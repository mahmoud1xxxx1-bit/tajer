import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

class RawMaterial {
  final String id;
  final String merchantId;
  final String name;
  final double quantity; // in smallest unit (e.g., grams, ml)
  final double initialQuantity; // total registered initially
  final String unit; // 'g', 'ml', 'piece'
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RawMaterial({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.quantity,
    required this.initialQuantity,
    required this.unit,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RawMaterial.fromJson(Map<String, dynamic> json) {
    return RawMaterial(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      initialQuantity: (json['initialQuantity'] as num?)?.toDouble() ?? (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'name': name,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'unit': unit,
      'isArchived': isArchived,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RawMaterial copyWith({
    String? id,
    String? merchantId,
    String? name,
    double? quantity,
    double? initialQuantity,
    String? unit,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RawMaterial(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      unit: unit ?? this.unit,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RecipeItem {
  final String rawMaterialId;
  final double amountRequired;

  const RecipeItem({
    required this.rawMaterialId,
    required this.amountRequired,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
      rawMaterialId: json['rawMaterialId'] as String,
      amountRequired: (json['amountRequired'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawMaterialId': rawMaterialId,
      'amountRequired': amountRequired,
    };
  }

  RecipeItem copyWith({
    String? rawMaterialId,
    double? amountRequired,
  }) {
    return RecipeItem(
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      amountRequired: amountRequired ?? this.amountRequired,
    );
  }
}

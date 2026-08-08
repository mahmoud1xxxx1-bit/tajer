import 'package:cloud_firestore/cloud_firestore.dart';
import 'branch.dart';

class BranchInventory {
  final String id;
  final String merchantId;
  final String branchId;
  final String itemId;
  final String itemType; // product | raw_material
  final double quantity;
  final double initialQuantity;
  final DateTime updatedAt;

  const BranchInventory({
    required this.id,
    required this.merchantId,
    required this.branchId,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.initialQuantity,
    required this.updatedAt,
  });

  factory BranchInventory.fromJson(Map<String, dynamic> json) {
    final rawUpdatedAt = json['updatedAt'];
    DateTime parsedUpdatedAt;
    if (rawUpdatedAt is Timestamp) {
      parsedUpdatedAt = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    return BranchInventory(
      id: json['id']?.toString() ?? '',
      merchantId: json['merchantId']?.toString() ?? '',
      branchId: resolveBranchId(json['branchId']),
      itemId: json['itemId']?.toString() ?? '',
      itemType: json['itemType']?.toString() ?? 'product',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      initialQuantity: (json['initialQuantity'] as num?)?.toDouble() ?? 0.0,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchantId': merchantId,
        'branchId': branchId,
        'itemId': itemId,
        'itemType': itemType,
        'quantity': quantity,
        'initialQuantity': initialQuantity,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  BranchInventory copyWith({
    double? quantity,
    double? initialQuantity,
    DateTime? updatedAt,
  }) {
    return BranchInventory(
      id: id,
      merchantId: merchantId,
      branchId: branchId,
      itemId: itemId,
      itemType: itemType,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

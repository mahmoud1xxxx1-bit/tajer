import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryTransfer {
  final String id;
  final String merchantId;
  final String fromBranchId;
  final String toBranchId;
  final String itemId;
  final String itemName;
  final String itemType;
  final double quantity;
  final double sourceQuantityBefore;
  final double sourceQuantityAfter;
  final double destinationQuantityBefore;
  final double destinationQuantityAfter;
  final String status;
  final String? note;
  final String? createdByEmail;
  final String? createdByName;
  final DateTime createdAt;

  const InventoryTransfer({
    required this.id,
    required this.merchantId,
    required this.fromBranchId,
    required this.toBranchId,
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.quantity,
    required this.sourceQuantityBefore,
    required this.sourceQuantityAfter,
    required this.destinationQuantityBefore,
    required this.destinationQuantityAfter,
    required this.status,
    this.note,
    this.createdByEmail,
    this.createdByName,
    required this.createdAt,
  });

  factory InventoryTransfer.fromJson(Map<String, dynamic> json) {
    final rawDate = json['createdAt'];
    final createdAt = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is DateTime
            ? rawDate
            : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();

    return InventoryTransfer(
      id: json['id']?.toString() ?? '',
      merchantId: json['merchantId']?.toString() ?? '',
      fromBranchId: json['fromBranchId']?.toString() ?? '',
      toBranchId: json['toBranchId']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      itemType: json['itemType']?.toString() ?? 'product',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      sourceQuantityBefore:
          (json['sourceQuantityBefore'] as num?)?.toDouble() ?? 0.0,
      sourceQuantityAfter:
          (json['sourceQuantityAfter'] as num?)?.toDouble() ?? 0.0,
      destinationQuantityBefore:
          (json['destinationQuantityBefore'] as num?)?.toDouble() ?? 0.0,
      destinationQuantityAfter:
          (json['destinationQuantityAfter'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'completed',
      note: json['note']?.toString(),
      createdByEmail: json['createdByEmail']?.toString(),
      createdByName: json['createdByName']?.toString(),
      createdAt: createdAt,
    );
  }
}

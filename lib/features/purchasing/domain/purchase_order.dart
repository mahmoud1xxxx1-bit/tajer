import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class PurchaseOrderLine {
  final String id;
  final String itemType;
  final String itemId;
  final String itemNameSnapshot;
  final double orderedQuantity;
  final double receivedQuantity;
  final double? unitCost;

  const PurchaseOrderLine({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.itemNameSnapshot,
    required this.orderedQuantity,
    this.receivedQuantity = 0.0,
    this.unitCost,
  });

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLine(
      id: json['id'] as String,
      itemType: json['itemType'] as String,
      itemId: json['itemId'] as String,
      itemNameSnapshot: json['itemNameSnapshot'] as String,
      orderedQuantity: (json['orderedQuantity'] as num).toDouble(),
      receivedQuantity: (json['receivedQuantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['unitCost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemType': itemType,
      'itemId': itemId,
      'itemNameSnapshot': itemNameSnapshot,
      'orderedQuantity': orderedQuantity,
      'receivedQuantity': receivedQuantity,
      'unitCost': unitCost,
    };
  }

  PurchaseOrderLine copyWith({
    double? receivedQuantity,
    double? unitCost,
  }) {
    return PurchaseOrderLine(
      id: id,
      itemType: itemType,
      itemId: itemId,
      itemNameSnapshot: itemNameSnapshot,
      orderedQuantity: orderedQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      unitCost: unitCost ?? this.unitCost,
    );
  }
}

@immutable
class PurchaseOrder {
  final String id;
  final String merchantId;
  final String branchId;
  final String supplierId;
  final String status; // draft, ordered, partiallyReceived, received, cancelled
  final DateTime createdAt;
  final String createdByUid;
  final List<PurchaseOrderLine> lines;

  const PurchaseOrder({
    required this.id,
    required this.merchantId,
    required this.branchId,
    required this.supplierId,
    required this.status,
    required this.createdAt,
    required this.createdByUid,
    this.lines = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      branchId: json['branchId'] as String,
      supplierId: json['supplierId'] as String,
      status: json['status'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      createdByUid: json['createdByUid'] as String,
      lines: (json['lines'] as List<dynamic>?)
              ?.map((e) => PurchaseOrderLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'branchId': branchId,
      'supplierId': supplierId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUid': createdByUid,
      'lines': lines.map((e) => e.toJson()).toList(),
    };
  }

  PurchaseOrder copyWith({
    String? id,
    String? status,
    List<PurchaseOrderLine>? lines,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      merchantId: merchantId,
      branchId: branchId,
      supplierId: supplierId,
      status: status ?? this.status,
      createdAt: createdAt,
      createdByUid: createdByUid,
      lines: lines ?? this.lines,
    );
  }
}

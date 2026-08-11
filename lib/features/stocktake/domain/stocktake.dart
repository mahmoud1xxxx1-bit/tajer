import 'package:cloud_firestore/cloud_firestore.dart';

class StocktakeLine {
  final String id;
  final String itemType; // 'product' or 'raw_material'
  final String itemId;
  final String itemNameSnapshot;
  final double expectedQuantityAtStart;
  final double countedQuantity;
  final double difference;
  final String? reason;
  final String? note;
  final String countedBy;
  final DateTime countedAt;
  final bool applied;
  final DateTime? appliedAt;

  StocktakeLine({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.itemNameSnapshot,
    required this.expectedQuantityAtStart,
    required this.countedQuantity,
    required this.difference,
    this.reason,
    this.note,
    required this.countedBy,
    required this.countedAt,
    this.applied = false,
    this.appliedAt,
  });

  factory StocktakeLine.fromJson(Map<String, dynamic> json) {
    return StocktakeLine(
      id: json['id'] as String,
      itemType: json['itemType'] as String,
      itemId: json['itemId'] as String,
      itemNameSnapshot: json['itemNameSnapshot'] as String,
      expectedQuantityAtStart: (json['expectedQuantityAtStart'] as num).toDouble(),
      countedQuantity: (json['countedQuantity'] as num).toDouble(),
      difference: (json['difference'] as num).toDouble(),
      reason: json['reason'] as String?,
      note: json['note'] as String?,
      countedBy: json['countedBy'] as String,
      countedAt: (json['countedAt'] as Timestamp).toDate(),
      applied: json['applied'] as bool? ?? false,
      appliedAt: json['appliedAt'] != null ? (json['appliedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemType': itemType,
      'itemId': itemId,
      'itemNameSnapshot': itemNameSnapshot,
      'expectedQuantityAtStart': expectedQuantityAtStart,
      'countedQuantity': countedQuantity,
      'difference': difference,
      'reason': reason,
      'note': note,
      'countedBy': countedBy,
      'countedAt': Timestamp.fromDate(countedAt),
      'applied': applied,
      'appliedAt': appliedAt != null ? Timestamp.fromDate(appliedAt!) : null,
    };
  }
}

class StocktakeSession {
  final String id;
  final String merchantId;
  final String branchId;
  final String status; // 'draft', 'counting', 'review', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String createdByUid;
  final String createdByName;
  final int totalLines;
  final int countedLines;
  final int varianceLines;

  StocktakeSession({
    required this.id,
    required this.merchantId,
    required this.branchId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.createdByUid,
    required this.createdByName,
    this.totalLines = 0,
    this.countedLines = 0,
    this.varianceLines = 0,
  });

  factory StocktakeSession.fromJson(Map<String, dynamic> json) {
    return StocktakeSession(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      branchId: json['branchId'] as String,
      status: json['status'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      startedAt: json['startedAt'] != null ? (json['startedAt'] as Timestamp).toDate() : null,
      completedAt: json['completedAt'] != null ? (json['completedAt'] as Timestamp).toDate() : null,
      createdByUid: json['createdByUid'] as String,
      createdByName: json['createdByName'] as String,
      totalLines: json['totalLines'] as int? ?? 0,
      countedLines: json['countedLines'] as int? ?? 0,
      varianceLines: json['varianceLines'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'branchId': branchId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'totalLines': totalLines,
      'countedLines': countedLines,
      'varianceLines': varianceLines,
    };
  }
}

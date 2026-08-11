import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class ActionAlert {
  final String id;
  final String merchantId;
  final String? branchId;
  final String type;
  final String severity;
  final String sourceType;
  final String sourceId;
  final String fingerprint;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? actionDestination;
  final Map<String, dynamic> metadata;

  const ActionAlert({
    required this.id,
    required this.merchantId,
    this.branchId,
    required this.type,
    required this.severity,
    required this.sourceType,
    required this.sourceId,
    required this.fingerprint,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.actionDestination,
    this.metadata = const {},
  });

  factory ActionAlert.fromJson(Map<String, dynamic> json) {
    return ActionAlert(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      branchId: json['branchId'] as String?,
      type: json['type'] as String,
      severity: json['severity'] as String,
      sourceType: json['sourceType'] as String,
      sourceId: json['sourceId'] as String,
      fingerprint: json['fingerprint'] as String,
      status: json['status'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      resolvedAt: json['resolvedAt'] != null ? (json['resolvedAt'] as Timestamp).toDate() : null,
      actionDestination: json['actionDestination'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'branchId': branchId,
      'type': type,
      'severity': severity,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'fingerprint': fingerprint,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'actionDestination': actionDestination,
      'metadata': metadata,
    };
  }

  ActionAlert copyWith({
    String? status,
    DateTime? resolvedAt,
  }) {
    return ActionAlert(
      id: id,
      merchantId: merchantId,
      branchId: branchId,
      type: type,
      severity: severity,
      sourceType: sourceType,
      sourceId: sourceId,
      fingerprint: fingerprint,
      status: status ?? this.status,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      actionDestination: actionDestination,
      metadata: metadata,
    );
  }
}

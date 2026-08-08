import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerDebtAllocation {
  final String orderId;
  final double amount;

  const CustomerDebtAllocation({
    required this.orderId,
    required this.amount,
  });

  factory CustomerDebtAllocation.fromJson(Map<String, dynamic> json) {
    return CustomerDebtAllocation(
      orderId: json['orderId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'amount': amount,
      };
}

/// Immutable provenance record for a customer debt collection.
///
/// Customer balances remain merchant-wide, while every collection records the
/// branch and (when applicable) shift that actually received the money.
class CustomerDebtPayment {
  final String id;
  final String merchantId;
  final String customerId;
  final String branchId;
  final String? shiftId;
  final double amount;
  final String paymentMethod;
  final List<CustomerDebtAllocation> allocations;
  final DateTime createdAt;

  const CustomerDebtPayment({
    required this.id,
    required this.merchantId,
    required this.customerId,
    this.branchId = 'main',
    this.shiftId,
    required this.amount,
    required this.paymentMethod,
    this.allocations = const [],
    required this.createdAt,
  });

  factory CustomerDebtPayment.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else {
      createdAt = DateTime.tryParse(rawCreatedAt?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return CustomerDebtPayment(
      id: json['id']?.toString() ?? '',
      merchantId: json['merchantId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      // Defensive fallback is primarily for staged/early multi-branch records.
      branchId: json['branchId']?.toString() ?? 'main',
      shiftId: json['shiftId']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      allocations: (json['allocations'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => CustomerDebtAllocation.fromJson(
                Map<String, dynamic>.from(value),
              ))
          .toList(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchantId': merchantId,
        'customerId': customerId,
        'branchId': branchId,
        'shiftId': shiftId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'allocations': allocations.map((value) => value.toJson()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

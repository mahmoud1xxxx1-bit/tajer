import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class DailySummary {
  final String id; // format: YYYY-MM-DD
  final String merchantId;
  final DateTime date;
  
  final double sales;
  final int ordersCount;
  final double expenses;
  final double vat;
  final double customerDebtCollection;
  final double supplierPayments;
  final double shiftDiscrepancy;
  final int inventoryAttentionCount;
  
  final Map<String, dynamic> branchBreakdown;

  // Computed / Optional based on permissions
  final double cogs;
  final double profit;
  final bool cogsIncomplete;

  const DailySummary({
    required this.id,
    required this.merchantId,
    required this.date,
    required this.sales,
    required this.ordersCount,
    required this.expenses,
    required this.vat,
    required this.customerDebtCollection,
    required this.supplierPayments,
    required this.shiftDiscrepancy,
    required this.inventoryAttentionCount,
    required this.branchBreakdown,
    required this.cogs,
    required this.profit,
    required this.cogsIncomplete,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      date: (json['date'] as Timestamp).toDate(),
      sales: (json['sales'] as num).toDouble(),
      ordersCount: json['ordersCount'] as int,
      expenses: (json['expenses'] as num).toDouble(),
      vat: (json['vat'] as num).toDouble(),
      customerDebtCollection: (json['customerDebtCollection'] as num).toDouble(),
      supplierPayments: (json['supplierPayments'] as num).toDouble(),
      shiftDiscrepancy: (json['shiftDiscrepancy'] as num).toDouble(),
      inventoryAttentionCount: json['inventoryAttentionCount'] as int,
      branchBreakdown: json['branchBreakdown'] as Map<String, dynamic>,
      cogs: (json['cogs'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      cogsIncomplete: json['cogsIncomplete'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'date': Timestamp.fromDate(date),
      'sales': sales,
      'ordersCount': ordersCount,
      'expenses': expenses,
      'vat': vat,
      'customerDebtCollection': customerDebtCollection,
      'supplierPayments': supplierPayments,
      'shiftDiscrepancy': shiftDiscrepancy,
      'inventoryAttentionCount': inventoryAttentionCount,
      'branchBreakdown': branchBreakdown,
      'cogs': cogs,
      'profit': profit,
      'cogsIncomplete': cogsIncomplete,
    };
  }
}

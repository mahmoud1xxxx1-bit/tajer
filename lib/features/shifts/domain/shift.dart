import 'package:cloud_firestore/cloud_firestore.dart';

class Shift {
  final String id;
  final String merchantId;
  final String employeeId;
  final String employeeName;
  final DateTime startTime;
  final DateTime? endTime;
  final double startCash; // العهدة الافتتاحية
  final double? expectedCash; // الكاش المتوقع عند الإغلاق
  final double? actualCash; // الكاش الفعلي المدخل من قبل الموظف
  final double? cardTotal; // إجمالي مبيعات مدى وغيرها
  final double? transferTotal; // إجمالي مبيعات التحويل
  final double? cashSales; // المبيعات النقدية فقط خلال الوردية
  final String status; // 'open', 'closed'

  Shift({
    required this.id,
    required this.merchantId,
    required this.employeeId,
    required this.employeeName,
    required this.startTime,
    this.endTime,
    required this.startCash,
    this.expectedCash,
    this.actualCash,
    this.cardTotal,
    this.transferTotal,
    this.cashSales,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'startTime': startTime,
      'endTime': endTime,
      'startCash': startCash,
      'expectedCash': expectedCash,
      'actualCash': actualCash,
      'cardTotal': cardTotal,
      'transferTotal': transferTotal,
      'cashSales': cashSales,
      'status': status,
    };
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] ?? '',
      merchantId: json['merchantId'] ?? '',
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: json['endTime'] != null ? (json['endTime'] as Timestamp).toDate() : null,
      startCash: (json['startCash'] ?? 0.0).toDouble(),
      expectedCash: json['expectedCash']?.toDouble(),
      actualCash: json['actualCash']?.toDouble(),
      cardTotal: json['cardTotal']?.toDouble(),
      transferTotal: json['transferTotal']?.toDouble(),
      cashSales: json['cashSales']?.toDouble(),
      status: json['status'] ?? 'open',
    );
  }

  Shift copyWith({
    String? id,
    String? merchantId,
    String? employeeId,
    String? employeeName,
    DateTime? startTime,
    DateTime? endTime,
    double? startCash,
    double? expectedCash,
    double? actualCash,
    double? cardTotal,
    double? transferTotal,
    double? cashSales,
    String? status,
  }) {
    return Shift(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startCash: startCash ?? this.startCash,
      expectedCash: expectedCash ?? this.expectedCash,
      actualCash: actualCash ?? this.actualCash,
      cardTotal: cardTotal ?? this.cardTotal,
      transferTotal: transferTotal ?? this.transferTotal,
      cashSales: cashSales ?? this.cashSales,
      status: status ?? this.status,
    );
  }
}

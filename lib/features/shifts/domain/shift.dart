import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

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
  final double? actualCard; // مبيعات مدى الفعلية
  final double? actualTransfer; // مبيعات التحويل الفعلية
  final double? cardTotal; // إجمالي مبيعات مدى وغيرها
  final double? transferTotal; // إجمالي مبيعات التحويل
  final double? cashSales; // المبيعات النقدية فقط خلال الوردية
  final double? debtCollectionsCash; // الديون المحصلة كاش خلال الوردية
  final double? debtCollectionsCard; // الديون المحصلة مدى خلال الوردية
  final double? debtCollectionsTransfer; // الديون المحصلة حوالة بنكية خلال الوردية
  final double? totalTax; // إجمالي الضريبة المحصلة
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
    this.actualCard,
    this.actualTransfer,
    this.cardTotal,
    this.transferTotal,
    this.cashSales,
    this.debtCollectionsCash,
    this.debtCollectionsCard,
    this.debtCollectionsTransfer,
    this.totalTax,
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
      'actualCard': actualCard,
      'actualTransfer': actualTransfer,
      'cardTotal': cardTotal,
      'transferTotal': transferTotal,
      'cashSales': cashSales,
      'debtCollectionsCash': debtCollectionsCash,
      'debtCollectionsCard': debtCollectionsCard,
      'debtCollectionsTransfer': debtCollectionsTransfer,
      'totalTax': totalTax,
      'status': status,
    };
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] ?? '',
      merchantId: json['merchantId'] ?? '',
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      startTime: safeParseDate(json['startTime']),
      endTime: safeParseNullableDate(json['endTime']),
      startCash: (json['startCash'] ?? 0.0).toDouble(),
      expectedCash: json['expectedCash']?.toDouble(),
      actualCash: json['actualCash']?.toDouble(),
      actualCard: json['actualCard']?.toDouble(),
      actualTransfer: json['actualTransfer']?.toDouble(),
      cardTotal: json['cardTotal']?.toDouble(),
      transferTotal: json['transferTotal']?.toDouble(),
      cashSales: json['cashSales']?.toDouble(),
      debtCollectionsCash: json['debtCollectionsCash']?.toDouble(),
      debtCollectionsCard: json['debtCollectionsCard']?.toDouble(),
      debtCollectionsTransfer: json['debtCollectionsTransfer']?.toDouble(),
      totalTax: json['totalTax']?.toDouble(),
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
    double? actualCard,
    double? actualTransfer,
    double? cardTotal,
    double? transferTotal,
    double? cashSales,
    double? debtCollectionsCash,
    double? debtCollectionsCard,
    double? debtCollectionsTransfer,
    double? totalTax,
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
      actualCard: actualCard ?? this.actualCard,
      actualTransfer: actualTransfer ?? this.actualTransfer,
      cardTotal: cardTotal ?? this.cardTotal,
      transferTotal: transferTotal ?? this.transferTotal,
      cashSales: cashSales ?? this.cashSales,
      debtCollectionsCash: debtCollectionsCash ?? this.debtCollectionsCash,
      debtCollectionsCard: debtCollectionsCard ?? this.debtCollectionsCard,
      debtCollectionsTransfer: debtCollectionsTransfer ?? this.debtCollectionsTransfer,
      totalTax: totalTax ?? this.totalTax,
      status: status ?? this.status,
    );
  }
}

import '../../../core/utils/date_parser.dart';

class Shift {
  final String id;
  final String merchantId;
  final String branchId;
  final String employeeId;
  final String employeeName;
  final DateTime startTime;
  final DateTime? endTime;
  final double startCash;
  final double? expectedCash;
  final double? actualCash;
  final double? actualCard;
  final double? actualTransfer;
  final double? cardTotal;
  final double? transferTotal;
  final double? cashSales;
  final double? debtCollectionsCash;
  final double? debtCollectionsCard;
  final double? debtCollectionsTransfer;
  final double? refundsCash;
  final double? refundsCard;
  final double? refundsTransfer;
  final double? totalTax;
  final String status;

  const Shift({
    required this.id,
    required this.merchantId,
    this.branchId = 'main',
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
    this.refundsCash,
    this.refundsCard,
    this.refundsTransfer,
    this.totalTax,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'branchId': branchId,
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
      'refundsCash': refundsCash,
      'refundsCard': refundsCard,
      'refundsTransfer': refundsTransfer,
      'totalTax': totalTax,
      'status': status,
    };
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id']?.toString() ?? '',
      merchantId: json['merchantId']?.toString() ?? '',
      branchId: json['branchId']?.toString() ?? 'main',
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      startTime: safeParseDate(json['startTime']),
      endTime: safeParseNullableDate(json['endTime']),
      startCash: (json['startCash'] as num? ?? 0.0).toDouble(),
      expectedCash: (json['expectedCash'] as num?)?.toDouble(),
      actualCash: (json['actualCash'] as num?)?.toDouble(),
      actualCard: (json['actualCard'] as num?)?.toDouble(),
      actualTransfer: (json['actualTransfer'] as num?)?.toDouble(),
      cardTotal: (json['cardTotal'] as num?)?.toDouble(),
      transferTotal: (json['transferTotal'] as num?)?.toDouble(),
      cashSales: (json['cashSales'] as num?)?.toDouble(),
      debtCollectionsCash: (json['debtCollectionsCash'] as num?)?.toDouble(),
      debtCollectionsCard: (json['debtCollectionsCard'] as num?)?.toDouble(),
      debtCollectionsTransfer: (json['debtCollectionsTransfer'] as num?)?.toDouble(),
      refundsCash: (json['refundsCash'] as num?)?.toDouble(),
      refundsCard: (json['refundsCard'] as num?)?.toDouble(),
      refundsTransfer: (json['refundsTransfer'] as num?)?.toDouble(),
      totalTax: (json['totalTax'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'open',
    );
  }

  Shift copyWith({
    String? id,
    String? merchantId,
    String? branchId,
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
    double? refundsCash,
    double? refundsCard,
    double? refundsTransfer,
    double? totalTax,
    String? status,
  }) {
    return Shift(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      branchId: branchId ?? this.branchId,
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
      refundsCash: refundsCash ?? this.refundsCash,
      refundsCard: refundsCard ?? this.refundsCard,
      refundsTransfer: refundsTransfer ?? this.refundsTransfer,
      totalTax: totalTax ?? this.totalTax,
      status: status ?? this.status,
    );
  }
}

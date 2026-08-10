import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class PurchaseInvoiceItem {
  final String itemId; // can be rawMaterialId or productId
  final String itemName;
  final String itemType; // 'product' or 'raw_material'
  final double quantity;
  final double unitCost;
  final double totalCost;

  const PurchaseInvoiceItem({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
  });

  factory PurchaseInvoiceItem.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceItem(
      itemId: json['itemId'] as String,
      itemName: json['itemName'] as String,
      itemType: json['itemType'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitCost: (json['unitCost'] as num).toDouble(),
      totalCost: (json['totalCost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemType': itemType,
      'quantity': quantity,
      'unitCost': unitCost,
      'totalCost': totalCost,
    };
  }
}

class PurchaseInvoice {
  final String id;
  final String merchantId;
  final String branchId;
  final String supplierId;
  final String supplierName;
  final String invoiceNumber;
  final List<PurchaseInvoiceItem> items;
  final double totalAmount;
  final double amountPaid;
  final String paymentMethod;
  final bool isFromShiftDrawer;
  final String? shiftId;
  final String? expenseId;
  final String? supplierTransactionId;
  final String? creatorId;
  final String? creatorName;
  final DateTime createdAt;

  const PurchaseInvoice({
    required this.id,
    required this.merchantId,
    required this.branchId,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceNumber,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentMethod,
    required this.isFromShiftDrawer,
    this.shiftId,
    this.expenseId,
    this.supplierTransactionId,
    this.creatorId,
    this.creatorName,
    required this.createdAt,
  });

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoice(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      branchId: json['branchId'] as String? ?? 'main',
      supplierId: json['supplierId'] as String,
      supplierName: json['supplierName'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PurchaseInvoiceItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      totalAmount: (json['totalAmount'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      isFromShiftDrawer: json['isFromShiftDrawer'] as bool? ?? false,
      shiftId: json['shiftId'] as String?,
      expenseId: json['expenseId'] as String?,
      supplierTransactionId: json['supplierTransactionId'] as String?,
      creatorId: json['creatorId'] as String?,
      creatorName: json['creatorName'] as String?,
      createdAt: safeParseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'branchId': branchId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'invoiceNumber': invoiceNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'paymentMethod': paymentMethod,
      'isFromShiftDrawer': isFromShiftDrawer,
      'shiftId': shiftId,
      'expenseId': expenseId,
      'supplierTransactionId': supplierTransactionId,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

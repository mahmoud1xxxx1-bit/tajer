import 'package:tajer/features/products/domain/product.dart';

class CartItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double total;
  final List<String> selectedModifiers;
  final bool? isTaxInclusive;
  final double? taxPercentage;
  final TaxMode taxMode;
  final double? costPrice; // Task 6: Optional COGS value per item at time of sale

  const CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    this.selectedModifiers = const [],
    this.isTaxInclusive,
    this.taxPercentage,
    this.taxMode = TaxMode.store,
    this.costPrice,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: (json['quantity'] ?? 0).toInt(),
      price: (json['price'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 0.0).toDouble(),
      selectedModifiers: (json['selectedModifiers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isTaxInclusive: json['isTaxInclusive'] as bool?,
      taxPercentage: json['taxPercentage'] != null ? (json['taxPercentage'] as num).toDouble() : null,
      taxMode: _parseTaxMode(json['taxMode']),
      costPrice: json['costPrice'] != null ? (json['costPrice'] as num).toDouble() : null,
    );
  }

  static TaxMode _parseTaxMode(dynamic value) {
    if (value == null) return TaxMode.store;
    if (value is String) {
      for (final mode in TaxMode.values) {
        if (mode.name == value) return mode;
      }
    }
    return TaxMode.store;
  }

  double getEffectiveTax(double storeDefaultTax) {
    switch (taxMode) {
      case TaxMode.exempt:
        return 0.0;
      case TaxMode.custom:
        return taxPercentage ?? storeDefaultTax;
      case TaxMode.store:
      default:
        return storeDefaultTax;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
      'selectedModifiers': selectedModifiers,
      'isTaxInclusive': isTaxInclusive,
      'taxPercentage': taxPercentage,
      'taxMode': taxMode.name,
      'costPrice': costPrice,
    };
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? price,
    double? total,
    bool? isTaxInclusive,
    double? taxPercentage,
    TaxMode? taxMode,
    double? costPrice,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: total ?? this.total,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxMode: taxMode ?? this.taxMode,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}

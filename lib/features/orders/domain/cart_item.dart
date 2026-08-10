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
  final double? costPrice;
  final bool isManufacturedOnDemand;
  final String? lineId;
  final List<Map<String, dynamic>>? historicalMtoRecipe;

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
    this.isManufacturedOnDemand = false,
    this.lineId,
    this.historicalMtoRecipe,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: (json['quantity'] ?? 0).toInt(),
      price: (json['price'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 0.0).toDouble(),
      selectedModifiers: (json['selectedModifiers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isTaxInclusive: json['isTaxInclusive'] as bool?,
      taxPercentage: json['taxPercentage'] != null
          ? (json['taxPercentage'] as num).toDouble()
          : null,
      taxMode: _parseTaxMode(json['taxMode']),
      isManufacturedOnDemand: json['isManufacturedOnDemand'] as bool? ?? false,
      // Legacy v107 orders may still contain this field until the protected
      // historical-cost migration removes it. New public order writes never do.
      costPrice: json['costPrice'] != null
          ? (json['costPrice'] as num).toDouble()
          : null,
      lineId: json['lineId']?.toString(),
      historicalMtoRecipe: (json['historicalMtoRecipe'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
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
    if (taxMode == TaxMode.exempt) return 0.0;
    return taxPercentage ?? storeDefaultTax;
  }

  /// Full in-memory representation for trusted local calculations only.
  Map<String, dynamic> toJson() {
    return {
      ...toPublicJson(),
      'costPrice': costPrice,
    };
  }

  /// Safe payload used for /orders. Firestore cannot redact individual fields,
  /// so this preserves the v107 historical cost snapshot at sale time.
  Map<String, dynamic> toPublicJson() {
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
      'isManufacturedOnDemand': isManufacturedOnDemand,
      'costPrice': costPrice,
      'lineId': lineId,
      'historicalMtoRecipe': historicalMtoRecipe,
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
    bool? isManufacturedOnDemand,
    String? lineId,
    List<Map<String, dynamic>>? historicalMtoRecipe,
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
      isManufacturedOnDemand:
          isManufacturedOnDemand ?? this.isManufacturedOnDemand,
      lineId: lineId ?? this.lineId,
      historicalMtoRecipe: historicalMtoRecipe ?? this.historicalMtoRecipe,
    );
  }
}

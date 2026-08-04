class CartItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double total;
  final List<String> selectedModifiers;
  final bool? isTaxInclusive;
  final double? taxPercentage;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    this.selectedModifiers = const [],
    this.isTaxInclusive,
    this.taxPercentage,
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
    );
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
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: total ?? this.total,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      taxPercentage: taxPercentage ?? this.taxPercentage,
    );
  }
}

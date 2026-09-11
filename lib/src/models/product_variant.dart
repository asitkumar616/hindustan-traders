class ProductVariant {
  final String id;
  final String productId;
  final double quantity;
  final String unit;
  final String packageType;
  final double sellingPrice;
  final double minimumOrderQuantity;
  final double? stockQuantity;
  final bool isActive;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unit,
    required this.packageType,
    required this.sellingPrice,
    this.minimumOrderQuantity = 1,
    this.stockQuantity,
    this.isActive = true,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unit: map['unit']?.toString() ?? 'KG',
      packageType: map['package_type']?.toString() ?? 'LOOSE',
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
      minimumOrderQuantity: (map['minimum_order_quantity'] as num?)?.toDouble() ?? 1,
      stockQuantity: (map['stock_quantity'] as num?)?.toDouble(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  /// Display label such as "5 KG" or "25 KG BAG" -- omits the package type
  /// when it's just the loose/unpackaged default.
  String get label {
    final qty = quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();
    final base = '$qty $unit';
    return packageType == 'LOOSE' ? base : '$base $packageType';
  }
}

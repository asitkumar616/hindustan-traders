/// One line in the cart -- keyed by variant (not product), so "Rice 5 KG"
/// and "Rice 25 KG BAG" can both sit in the cart as distinct lines even
/// though they belong to the same product.
class CartLine {
  final String productId;
  final String variantId;
  final String productName;
  final String? brand;
  final double variantQuantity;
  final String variantUnit;
  final String packageType;
  final double price;
  final double quantity;
  final double minimumOrderQuantity;

  const CartLine({
    required this.productId,
    required this.variantId,
    required this.productName,
    this.brand,
    required this.variantQuantity,
    required this.variantUnit,
    required this.packageType,
    required this.price,
    required this.quantity,
    this.minimumOrderQuantity = 1,
  });

  double get amount => price * quantity;

  /// "25 KG BAG" style label for the selected variant.
  String get variantLabel {
    final qty = variantQuantity == variantQuantity.roundToDouble()
        ? variantQuantity.toInt().toString()
        : variantQuantity.toString();
    final base = '$qty $variantUnit';
    return packageType == 'LOOSE' ? base : '$base $packageType';
  }
}

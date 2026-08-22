class CartLine {
  final String productId;
  final String name;
  final String unit;
  final double price;
  final double quantity;

  const CartLine({
    required this.productId,
    required this.name,
    required this.unit,
    required this.price,
    required this.quantity,
  });

  double get amount => price * quantity;
}

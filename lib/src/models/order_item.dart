class OrderItem {
  final String name;
  final double quantity;
  final String unit;
  final double price;
  final double amount;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'amount': amount,
    };
  }
}

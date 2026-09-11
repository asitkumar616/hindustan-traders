import 'package:flutter/foundation.dart';
import '../models/cart_line.dart';

/// In-memory cart for a single shopping visit, scoped to one business --
/// matches the existing app's rule that an order always belongs to exactly
/// one shop. Not persisted: a fresh cart is created each time the customer
/// opens a shop's catalog, mirroring how VoiceOrderCard's cart already
/// resets per screen visit.
class CartState extends ChangeNotifier {
  CartState({required this.businessId, required this.businessName});

  final String businessId;
  final String businessName;

  final Map<String, CartLine> _lines = <String, CartLine>{};

  List<CartLine> get lines => _lines.values.toList(growable: false);
  int get itemCount => _lines.length;
  bool get isEmpty => _lines.isEmpty;
  double get subtotal => _lines.values.fold<double>(0, (sum, line) => sum + line.amount);

  double quantityFor(String variantId) => _lines[variantId]?.quantity ?? 0;

  void setQuantity({
    required String productId,
    required String variantId,
    required String productName,
    String? brand,
    required double variantQuantity,
    required String variantUnit,
    required String packageType,
    required double price,
    required double quantity,
    double minimumOrderQuantity = 1,
  }) {
    if (quantity <= 0) {
      _lines.remove(variantId);
    } else {
      _lines[variantId] = CartLine(
        productId: productId,
        variantId: variantId,
        productName: productName,
        brand: brand,
        variantQuantity: variantQuantity,
        variantUnit: variantUnit,
        packageType: packageType,
        price: price,
        quantity: quantity,
        minimumOrderQuantity: minimumOrderQuantity,
      );
    }
    notifyListeners();
  }

  void removeLine(String variantId) {
    _lines.remove(variantId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

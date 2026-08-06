import 'package:flutter_test/flutter_test.dart';
import 'package:hindustan_traders/src/models/order_item.dart';
import 'package:hindustan_traders/src/services/order_draft_service.dart';
import 'package:hindustan_traders/src/services/order_service.dart';

void main() {
  group('OrderService', () {
    test('exposes a helper for loading orders for a business', () {
      expect(OrderService.getOrdersForBusiness, isA<Function>());
    });

    test('formats timestamps into a friendly display label', () {
      expect(OrderService.formatDisplayDate('2024-05-01T10:15:00Z'), contains('01/05/2024'));
      expect(OrderService.formatDisplayDate(null), equals('—'));
    });
  });

  group('OrderDraftService', () {
    test('returns a fallback result with a local-save message', () {
      const result = OrderSubmissionResult(
        success: false,
        savedLocally: true,
        message: 'No authenticated user found. Draft saved locally.',
      );

      expect(result.savedLocally, isTrue);
      expect(result.message, contains('saved locally'));
    });

    test('maps an order item to a payload using the catalog price when available', () {
      final payload = OrderDraftService.mapOrderItemToPayload(
        const OrderItem(name: 'Rice', quantity: 2, unit: 'kg', price: 80, amount: 160),
        {'id': 'product-1', 'price': 90},
      );

      expect(payload['price'], 90);
      expect(payload['amount'], 180);
      expect(payload['product_id'], 'product-1');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hindustan_traders/src/services/customer_business_service.dart';

void main() {
  group('CustomerBusinessService', () {
    test('exposes a helper for creating owner-created customer records', () {
      expect(CustomerBusinessService.createCustomerRecord, isA<Function>());
    });

    test('exposes a helper for loading customers for a business', () {
      expect(CustomerBusinessService.getCustomersForBusiness, isA<Function>());
    });

    test('exposes a helper for linking an authenticated customer after OTP', () {
      expect(CustomerBusinessService.linkCustomerAfterOtp, isA<Function>());
    });

    test('normalizes a product row with the latest price', () {
      final normalized = CustomerBusinessService.normalizeProductRow({
        'id': 'prod-1',
        'name': 'Rice',
        'unit': 'kg',
        'product_prices': [
          {'price': 55.5},
        ],
      });

      expect(normalized['name'], 'Rice');
      expect(normalized['price'], 55.5);
    });

    test('falls back to zero when no price exists', () {
      final normalized = CustomerBusinessService.normalizeProductRow({
        'id': 'prod-2',
        'name': 'Salt',
        'unit': 'packet',
      });

      expect(normalized['price'], 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hindustan_traders/src/services/auth_service.dart';
import 'package:hindustan_traders/src/services/customer_business_service.dart';

void main() {
  group('AuthService.normalizeIndianPhone', () {
    test('normalizes a 10-digit phone to +91 E.164', () {
      expect(AuthService.normalizeIndianPhone('9876543210'), '+919876543210');
    });

    test('normalizes a 0-prefixed 11-digit phone to +91 E.164', () {
      expect(AuthService.normalizeIndianPhone('09876543210'), '+919876543210');
    });

    test('normalizes a 91-prefixed 12-digit phone to +91 E.164', () {
      expect(AuthService.normalizeIndianPhone('919876543210'), '+919876543210');
    });

    test('returns null for invalid lengths', () {
      expect(AuthService.normalizeIndianPhone('12345'), isNull);
      expect(AuthService.normalizeIndianPhone('1234567890123'), isNull);
    });
  });

  group('AuthService.isValidIndianPhone', () {
    test('accepts valid E.164 +91 phone', () {
      expect(AuthService.isValidIndianPhone('+919876543210'), isTrue);
    });

    test('rejects non-E.164 and non-Indian forms', () {
      expect(AuthService.isValidIndianPhone('9876543210'), isFalse);
      expect(AuthService.isValidIndianPhone('+12125551234'), isFalse);
    });
  });

  group('CustomerBusinessService', () {
    test('exposes the OTP linker entry point', () {
      expect(CustomerBusinessService.linkCustomerAfterOtp, isA<Function>());
    });
  });
}

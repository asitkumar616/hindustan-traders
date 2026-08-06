import 'package:flutter_test/flutter_test.dart';
import 'package:hindustan_traders/src/services/auth_service.dart';

void main() {
  group('AuthService onboarding helpers', () {
    test('normalizes owner and business names with safe fallbacks', () {
      expect(AuthService.normalizeOwnerName('  Asha  '), 'Asha');
      expect(AuthService.normalizeOwnerName(null), 'Owner');
      expect(AuthService.normalizeBusinessName('  ABC Wholesale  '), 'ABC Wholesale');
      expect(AuthService.normalizeBusinessName(null), 'My Shop');
    });

    test('exposes a helper for resolving the current profile', () {
      expect(AuthService.getCurrentProfile, isA<Function>());
    });
  });
}

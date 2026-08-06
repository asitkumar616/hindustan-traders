import 'package:flutter_test/flutter_test.dart';
import 'package:hindustan_traders/src/models/user_profile.dart';
import 'package:hindustan_traders/src/services/role_router.dart';

void main() {
  group('RoleRouter onboarding routing', () {
    test('routes owners without a business to onboarding', () {
      final profile = UserProfile(id: '1', phone: '+911234567890', role: 'owner');

      expect(RoleRouter.shouldShowOwnerOnboarding(profile), isTrue);
    });

    test('routes owners with a business to the owner home screen', () {
      final profile = UserProfile(
        id: '1',
        phone: '+911234567890',
        role: 'owner',
        businessId: 'business-1',
      );

      expect(RoleRouter.shouldShowOwnerOnboarding(profile), isFalse);
    });
  });
}

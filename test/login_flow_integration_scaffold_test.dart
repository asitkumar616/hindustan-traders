import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'login integration scaffold: send OTP -> verify OTP -> route by role',
    () {
      // TODO:
      // 1) Pump app with a test Supabase client/mocked AuthService.
      // 2) Enter normalized phone and tap Send OTP.
      // 3) Enter OTP and verify profile fetch/create is called.
      // 4) Assert customer/owner route based on returned role.
      // 5) Assert validation messages for invalid phone/OTP.
      expect(true, isTrue);
    },
    skip: 'Scaffold only: requires Supabase test double wiring.',
  );
}

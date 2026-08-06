import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';
import '../services/role_router.dart';
import 'owner_onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _normalizedPhone;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final normalizedPhone = AuthService.normalizeIndianPhone(_phoneController.text.trim());
    if (normalizedPhone == null || !AuthService.isValidIndianPhone(normalizedPhone)) {
      final localized = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localized.translate('login_invalid_phone'))),
      );
      return;
    }

    setState(() => _sendingCode = true);
    try {
      await AuthService.signInWithPhone(normalizedPhone);
      if (!mounted) return;
      final localized = AppLocalizations.of(context);
      setState(() {
        _normalizedPhone = normalizedPhone;
        _codeSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localized.translate('login_otp_sent'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  Future<void> _verifyOtpAndContinue() async {
    final phone = _normalizedPhone;
    if (phone == null) {
      final localized = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localized.translate('login_send_otp_first'))),
      );
      return;
    }

    final token = _otpController.text.trim();
    if (token.length < 6) {
      final localized = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localized.translate('login_invalid_otp'))),
      );
      return;
    }

    setState(() => _verifyingCode = true);
    try {
      await AuthService.verifyOtp(phone: phone, token: token);
      final user = AuthService.currentUser;
      if (user == null) {
        throw Exception('OTP verification did not return a logged in user.');
      }

      final existingProfile = await AuthService.fetchProfileById(user.id);
      final linkedProfile = existingProfile != null
          ? await CustomerBusinessService.linkCustomerAfterOtp(
              phone: phone,
              userId: user.id,
              displayName: existingProfile.name ?? user.userMetadata?['name']?.toString(),
            ) ?? existingProfile
          : await CustomerBusinessService.linkCustomerAfterOtp(
              phone: phone,
              userId: user.id,
              displayName: user.userMetadata?['name']?.toString(),
            );
      if (!mounted) return;

      if (linkedProfile != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RoleRouter.routeForUser(linkedProfile, phone: phone)),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OwnerOnboardingScreen(phone: phone)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify OTP: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _verifyingCode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localized.translate('login_title'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(localized.translate('login_phone_label'), style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: localized.translate('login_phone_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendingCode ? null : _sendOtp,
              child: _sendingCode
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(localized.translate('login_send_otp')),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: localized.translate('login_otp_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _verifyingCode ? null : _verifyOtpAndContinue,
                child: _verifyingCode
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(localized.translate('login_verify_otp')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

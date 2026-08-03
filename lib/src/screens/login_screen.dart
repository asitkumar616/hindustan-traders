import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../localization/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _sendingCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _sendingCode = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _sendingCode = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent (mock)')));
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
              child: _sendingCode ? const CircularProgressIndicator(color: Colors.white) : Text(localized.translate('login_send_otp')),
            ),
          ],
        ),
      ),
    );
  }
}

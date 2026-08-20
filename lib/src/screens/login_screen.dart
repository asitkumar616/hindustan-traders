import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/role_router.dart';
import '../widgets/brand_logo.dart';
import 'admin_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _loggingIn = false;

  bool get _backendReady => context.read<AppState>().backendReady;

  void _showBackendUnavailableMessage() {
    final message = context.read<AppState>().backendStatus;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continueWithPhone() async {
    if (!_backendReady) {
      _showBackendUnavailableMessage();
      return;
    }

    final localized = AppLocalizations.of(context);
    final normalizedPhone = AuthService.normalizeIndianPhone(_phoneController.text.trim());
    if (normalizedPhone == null || !AuthService.isValidIndianPhone(normalizedPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localized.translate('login_invalid_phone'))),
      );
      return;
    }

    setState(() => _loggingIn = true);
    try {
      final profile = await AuthService.loginWithApprovedPhone(normalizedPhone);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoleRouter.routeForUser(profile, phone: normalizedPhone)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      final lower = message.toLowerCase();
      String displayMessage;
      if (lower.contains('not registered')) {
        displayMessage = localized.translate('login_mobile_not_allowed');
      } else if (lower.contains('not approved')) {
        displayMessage = localized.translate('login_mobile_not_approved');
      } else if (lower.contains('inactive')) {
        displayMessage = localized.translate('login_mobile_inactive');
      } else {
        // Authentication required, business-not-configured, DB/network errors, etc:
        // show the real backend message instead of a misleading generic one.
        displayMessage = message;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(displayMessage)));
    } finally {
      if (mounted) {
        setState(() => _loggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final localized = AppLocalizations.of(context);
    final backendReady = appState.backendReady;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(localized.translate('login_title'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Center(child: BrandLogo(size: 96, showLabel: true)),
                  const SizedBox(height: 32),
                  if (!backendReady) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              appState.backendStatus,
                              style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    localized.translate('login_phone_label'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                    decoration: InputDecoration(
                      hintText: localized.translate('login_phone_hint'),
                      prefixIcon: const Icon(Icons.phone_android_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: (_loggingIn || !backendReady) ? null : _continueWithPhone,
                    child: _loggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(localized.translate('login_continue')),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localized.translate('login_mobile_access_note'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: (_loggingIn)
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                              );
                            },
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                      label: const Text('Admin login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/role_router.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_primary_button.dart';
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
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 88, showLabel: true)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    localized.translate('splash_subtitle'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (!backendReady) ...[
                    AppErrorState(message: appState.backendStatus),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(localized.translate('login_title'), style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Enter your mobile number to continue',
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PhoneField(controller: _phoneController, hintText: localized.translate('login_phone_hint')),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: localized.translate('login_continue'),
                    onPressed: (_loggingIn || !backendReady) ? null : _continueWithPhone,
                    loading: _loggingIn,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    localized.translate('login_mobile_access_note'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, size: 16, color: colorScheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      const Text('Powered by Hindustan Traders', style: AppTextStyles.caption),
                    ],
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

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.lg),
            child: Text('+91', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            child: SizedBox(
              height: 24,
              child: VerticalDivider(color: colorScheme.outlineVariant, thickness: 1),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

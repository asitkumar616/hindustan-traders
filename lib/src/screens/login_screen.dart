import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/role_router.dart';
import '../theme/app_colors.dart';
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

  void _showComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign in with $provider is coming soon. Please use your mobile number for now.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final localized = AppLocalizations.of(context);
    final backendReady = appState.backendReady;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LogoHeader(localized: localized),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Welcome to', style: AppTextStyles.bodyMuted),
                                const SizedBox(height: 2),
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Odia',
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy),
                                      ),
                                      TextSpan(
                                        text: 'Traders',
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(localized.translate('login_title') == 'Login' ? 'Login to continue' : localized.translate('login_title'), style: AppTextStyles.bodyMuted),
                                const SizedBox(height: AppSpacing.xl),
                                if (!backendReady) ...[
                                  AppErrorState(message: appState.backendStatus),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                                _PhoneField(controller: _phoneController, hintText: localized.translate('login_phone_hint')),
                                const SizedBox(height: AppSpacing.lg),
                                AppPrimaryButton(
                                  label: localized.translate('login_continue'),
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: (_loggingIn || !backendReady) ? null : _continueWithPhone,
                                  loading: _loggingIn,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  localized.translate('login_mobile_access_note'),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: AppColors.divider)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                      child: Text('OR CONTINUE WITH', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                                    ),
                                    const Expanded(child: Divider(color: AppColors.divider)),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SocialButton(
                                        label: 'Google',
                                        icon: Icons.g_mobiledata_rounded,
                                        onTap: () => _showComingSoon('Google'),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: _SocialButton(
                                        label: 'Apple',
                                        icon: Icons.apple_rounded,
                                        onTap: () => _showComingSoon('Apple'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textSecondary),
                                    SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        'By continuing, you agree to our Terms & Conditions and Privacy Policy',
                                        style: AppTextStyles.caption,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const _FeatureRow(),
                          const SizedBox(height: AppSpacing.lg),
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
                    const _GroceryBand(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo + wordmark header, with the Odisha skyline as a faint backdrop --
/// mirrors the reference mockup's top section.
class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.localized});

  final AppLocalizations localized;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/images/illustrations/odisha_skyline.png',
              width: 220,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(size: 84, showLabel: false),
              const SizedBox(height: AppSpacing.sm),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Odia', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    TextSpan(text: 'Traders', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
              Text(localized.translate('splash_subtitle'), style: AppTextStyles.bodyMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _FeatureBadge(icon: Icons.sell_rounded, label: 'Better\nPrices', color: AppColors.primary),
          _FeatureBadge(icon: Icons.groups_rounded, label: 'Stronger\nBusinesses', color: AppColors.navy),
          _FeatureBadge(icon: Icons.bar_chart_rounded, label: 'Brighter\nOdisha', color: AppColors.success),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// Bottom photo band with a readability scrim -- mirrors the reference
/// mockup's grocery-sacks footer image.
class _GroceryBand extends StatelessWidget {
  const _GroceryBand();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/branding/splash_grocery.webp', fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            const Positioned(
              left: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Text(
                'Buy Better · Sell Smarter · Grow Together',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.lg),
            child: Icon(Icons.call_outlined, size: 18, color: AppColors.navy),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text('+91', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(color: AppColors.divider, thickness: 1),
          ),
          const SizedBox(width: AppSpacing.sm),
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

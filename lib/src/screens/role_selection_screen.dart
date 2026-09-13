import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/brand_logo.dart';
import 'admin_login_screen.dart';
import 'login_screen.dart';

enum _Role { customer, owner, admin }

/// A router/branding step, not a role override: the backend still decides
/// the real role from the phone number after login (Owner and Customer
/// both continue to the same phone-login screen and get auto-routed as
/// today). Only Admin actually diverges here, since Admin login is a
/// separate, non-phone-based flow that already exists.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  _Role _selected = _Role.customer;

  void _continue() {
    if (_selected == _Role.admin) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          BrandLogo(size: 44, showLabel: false),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: 'Odia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                                      TextSpan(text: 'Traders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                                Text('Wholesale Made Simple', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _LanguageChip(state: state),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
                child: Text('Welcome!', style: AppTextStyles.heading.copyWith(fontSize: 26, color: AppColors.navy)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 4, AppSpacing.xl, AppSpacing.xl),
                child: Text('Choose your role to continue', style: AppTextStyles.bodyMuted.copyWith(fontSize: 15)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    _RoleCard(
                      selected: _selected == _Role.customer,
                      onTap: () => setState(() => _selected = _Role.customer),
                      color: AppColors.navy,
                      icon: Icons.storefront_rounded,
                      title: 'Customer',
                      subtitle: 'Buy wholesale products',
                      features: const [
                        (Icons.shopping_cart_outlined, 'Browse\nProducts'),
                        (Icons.sell_outlined, 'Best\nPrices'),
                        (Icons.inventory_2_outlined, 'Easy\nOrdering'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RoleCard(
                      selected: _selected == _Role.owner,
                      onTap: () => setState(() => _selected = _Role.owner),
                      color: AppColors.primary,
                      icon: Icons.storefront_rounded,
                      title: 'Shop Owner',
                      subtitle: 'Sell products to retailers',
                      features: const [
                        (Icons.inventory_2_outlined, 'Manage\nProducts'),
                        (Icons.bar_chart_rounded, 'Track\nOrders'),
                        (Icons.groups_rounded, 'Grow\nBusiness'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RoleCard(
                      selected: _selected == _Role.admin,
                      onTap: () => setState(() => _selected = _Role.admin),
                      color: AppColors.categoryDal,
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin',
                      subtitle: 'Manage platform & users',
                      features: const [
                        (Icons.groups_rounded, 'Manage\nUsers'),
                        (Icons.description_outlined, 'View\nReports'),
                        (Icons.settings_outlined, 'Platform\nSettings'),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your data is safe with us', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(
                              'We use industry-standard security to protect your information.',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                child: AppPrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _continue,
                ),
              ),
              const _BottomBand(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.state});

  final AppState state;

  String get _label {
    switch (state.locale.languageCode) {
      case 'hi':
        return 'हिंदी';
      case 'or':
        return 'ଓଡ଼ିଆ';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Locale>(
      onSelected: state.setLocale,
      itemBuilder: (context) => const [
        PopupMenuItem(value: Locale('en'), child: Text('English')),
        PopupMenuItem(value: Locale('hi'), child: Text('हिंदी')),
        PopupMenuItem(value: Locale('or'), child: Text('ଓଡ଼ିଆ')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, size: 16, color: AppColors.navy),
            const SizedBox(width: 6),
            Text(_label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.onTap,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
  });

  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<(IconData, String)> features;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.bodyMuted),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? color : AppColors.divider,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: features
                  .map(
                    (f) => Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
                            child: Icon(f.$1, size: 16, color: color),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            f.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBand extends StatelessWidget {
  const _BottomBand();

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
                'Better Prices · Stronger Businesses · Brighter Odisha',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

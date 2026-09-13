import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/brand_logo.dart';
import 'role_selection_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final localized = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Center(child: BrandLogo(size: 64, showLabel: false)),
              const SizedBox(height: AppSpacing.xl),
              Text(
                localized.translate('language_prompt'),
                textAlign: TextAlign.center,
                style: AppTextStyles.heading.copyWith(color: AppColors.navy),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _LanguageButton(label: localized.translate('language_od'), locale: const Locale('or'), onTap: state.setLocale),
              const SizedBox(height: AppSpacing.md),
              _LanguageButton(label: localized.translate('language_hi'), locale: const Locale('hi'), onTap: state.setLocale),
              const SizedBox(height: AppSpacing.md),
              _LanguageButton(label: localized.translate('language_en'), locale: const Locale('en'), onTap: state.setLocale),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final Locale locale;
  final void Function(Locale) onTap;

  const _LanguageButton({required this.label, required this.locale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          onTap(locale);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.language_rounded, color: AppColors.navy, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(label, style: AppTextStyles.subheading.copyWith(fontSize: 17)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

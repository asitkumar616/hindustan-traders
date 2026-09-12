import 'dart:async';
import 'package:flutter/material.dart';
import 'language_selection_screen.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6EFFB), Color(0xFFF7FAFD)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const BrandLogo(size: 96, showLabel: false),
                const SizedBox(height: 18),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Odia',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: 0.3),
                      ),
                      TextSpan(
                        text: 'Traders',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  localized.translate('splash_subtitle'),
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const Spacer(flex: 2),
                const _GroceryIllustration(),
                const Spacer(flex: 2),
                const _FeatureRow(),
                const Spacer(flex: 2),
                const _PaginationDots(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroceryIllustration extends StatelessWidget {
  const _GroceryIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.asset(
            'assets/images/branding/splash_grocery.webp',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _FeatureBadge(icon: Icons.sell_rounded, label: 'Better Prices', color: AppColors.success),
        _FeatureBadge(icon: Icons.verified_rounded, label: 'Stronger Businesses', color: AppColors.info),
        _FeatureBadge(icon: Icons.auto_awesome_rounded, label: 'Brighter Odisha', color: AppColors.primary),
      ],
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
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _PaginationDots extends StatelessWidget {
  const _PaginationDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final active = index == 0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.navy : AppColors.divider,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'language_selection_screen.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
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
    Timer(const Duration(milliseconds: 1200), () {
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 108, showLabel: false),
              const SizedBox(height: 20),
              Text(
                localized.translate('app_name'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                localized.translate('splash_subtitle'),
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

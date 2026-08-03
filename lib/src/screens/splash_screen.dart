import 'dart:async';
import 'package:flutter/material.dart';
import 'language_selection_screen.dart';
import '../localization/app_localizations.dart';

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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront, size: 96, color: Colors.green),
            const SizedBox(height: 16),
            Text(localized.translate('app_name'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(localized.translate('splash_subtitle'), style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

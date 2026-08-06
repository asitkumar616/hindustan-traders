import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../localization/app_localizations.dart';
import 'login_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final localized = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localized.translate('language_title'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(localized.translate('language_prompt'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _LanguageButton(label: localized.translate('language_od'), locale: const Locale('or'), onTap: state.setLocale),
            const SizedBox(height: 12),
            _LanguageButton(label: localized.translate('language_hi'), locale: const Locale('hi'), onTap: state.setLocale),
            const SizedBox(height: 12),
            _LanguageButton(label: localized.translate('language_en'), locale: const Locale('en'), onTap: state.setLocale),
          ],
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
    return ElevatedButton(
      onPressed: () {
        onTap(locale);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      child: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }
}

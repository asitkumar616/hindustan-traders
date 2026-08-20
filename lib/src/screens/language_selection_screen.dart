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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              localized.translate('language_prompt'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          onTap(locale);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.language, color: colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

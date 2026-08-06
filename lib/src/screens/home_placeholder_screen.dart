import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localized.translate('app_name'))),
      body: Center(
        child: Text(localized.translate('home_placeholder'), style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

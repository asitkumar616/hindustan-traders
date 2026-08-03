import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppState extends ChangeNotifier {
  Locale _locale = const Locale('or');
  bool _initialized = false;

  Locale get locale => _locale;
  bool get initialized => _initialized;

  Future<void> init() async {
    await dotenv.load();
    final savedLanguage = dotenv.env['DEFAULT_LANGUAGE'];
    if (savedLanguage != null && savedLanguage.isNotEmpty) {
      _locale = Locale(savedLanguage);
    }
    _initialized = true;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}

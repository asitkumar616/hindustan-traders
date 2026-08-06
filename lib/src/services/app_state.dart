import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

class AppState extends ChangeNotifier {
  Locale _locale = const Locale('or');
  bool _initialized = false;

  Locale get locale => _locale;
  bool get initialized => _initialized;

  Future<void> init() async {
    await dotenv.load();

    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && !SupabaseService.isInitialized) {
      await SupabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey);
    }

    final savedLanguage = await LocalStorageService.getSavedLanguage();
    if (savedLanguage != null && savedLanguage.isNotEmpty) {
      _locale = Locale(savedLanguage);
    } else {
      final envLanguage = dotenv.env['DEFAULT_LANGUAGE'];
      if (envLanguage != null && envLanguage.isNotEmpty) {
        _locale = Locale(envLanguage);
      }
    }
    _initialized = true;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    LocalStorageService.saveLanguage(locale.languageCode);
    notifyListeners();
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

const String _defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String _defineSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

String _normalizeSupabaseUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';

  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    if (!value.contains('.')) {
      value = '$value.supabase.co';
    }
    value = 'https://$value';
  }

  return value;
}

bool _isValidSupabaseUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final validScheme = uri.scheme == 'https' || uri.scheme == 'http';
  return validScheme && uri.host.isNotEmpty;
}

class AppState extends ChangeNotifier {
  Locale _locale = const Locale('or');
  bool _initialized = false;
  bool _backendConfigured = false;
  bool _backendReady = false;
  String _backendStatus = 'Initializing backend...';

  Locale get locale => _locale;
  bool get initialized => _initialized;
  bool get backendConfigured => _backendConfigured;
  bool get backendReady => _backendReady;
  String get backendStatus => _backendStatus;

  Future<void> init() async {
    try {
      await dotenv.load();
    } catch (_) {
      // Continue with defaults when dotenv is missing.
    }

    try {
      // Flutter uses SUPABASE_URL / SUPABASE_ANON_KEY.
      // NEXT_PUBLIC_* is accepted as a compatibility fallback because the
      // repository previously contained a web/Next-style .env.
      final rawSupabaseUrl = (dotenv.env['SUPABASE_URL']?.trim().isNotEmpty ?? false)
          ? dotenv.env['SUPABASE_URL']!.trim()
          : ((dotenv.env['NEXT_PUBLIC_SUPABASE_URL']?.trim().isNotEmpty ?? false)
              ? dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!.trim()
              : _defineSupabaseUrl.trim());

      final supabaseUrl = _normalizeSupabaseUrl(rawSupabaseUrl);

      final supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty ?? false)
          ? dotenv.env['SUPABASE_ANON_KEY']!.trim()
          : ((dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY']?.trim().isNotEmpty ?? false)
              ? dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY']!.trim()
              : _defineSupabaseAnonKey.trim());
      _backendConfigured = rawSupabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
      if (!_backendConfigured) {
        _backendReady = false;
        _backendStatus =
            'Backend not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY in .env, then rebuild and reinstall APK.';
      } else if (!_isValidSupabaseUrl(supabaseUrl)) {
        _backendReady = false;
        _backendStatus =
            'Invalid SUPABASE_URL. Use project-ref.supabase.co or https://project-ref.supabase.co, then rebuild APK.';
      } else if (!SupabaseService.isInitialized) {
        await SupabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey).timeout(const Duration(seconds: 8));
        _backendReady = SupabaseService.isInitialized;
        _backendStatus = _backendReady
            ? 'Backend connected.'
            : 'Backend initialization failed. Please try again.';
      } else {
        _backendReady = true;
        _backendStatus = 'Backend connected.';
      }
    } catch (_) {
      // App should still boot even if backend init fails or times out.
      _backendReady = false;
      _backendStatus = 'Unable to connect backend. Check internet connection and Supabase settings.';
    }

    try {
      final savedLanguage = await LocalStorageService.getSavedLanguage();
      if (savedLanguage != null && savedLanguage.isNotEmpty) {
        _locale = Locale(savedLanguage);
      } else {
        final envLanguage = dotenv.env['DEFAULT_LANGUAGE'];
        if (envLanguage != null && envLanguage.isNotEmpty) {
          _locale = Locale(envLanguage);
        }
      }
    } catch (_) {
      // Keep default locale when local storage cannot be read.
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

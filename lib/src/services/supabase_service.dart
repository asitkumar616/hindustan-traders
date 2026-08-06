import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _initialized = false;

  static SupabaseClient get client => Supabase.instance.client;
  static bool get isInitialized => _initialized;

  static Future<void> init({required String url, required String anonKey}) async {
    if (_initialized) return;

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authCallbackUrlHostname: 'login-callback',
      debug: true,
    );

    _initialized = true;
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static SupabaseClient get _client {
    final client = _clientOrNull;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }
    return client;
  }

  static final RegExp _indiaE164Pattern = RegExp(r'^\+91\d{10}$');

  static String? normalizeIndianPhone(String rawPhone) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length == 10) {
      return '+91$digitsOnly';
    }

    if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
      return '+91${digitsOnly.substring(1)}';
    }

    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return '+$digitsOnly';
    }

    return null;
  }

  static bool isValidIndianPhone(String phone) {
    return _indiaE164Pattern.hasMatch(phone);
  }

  static String normalizeOwnerName(String? rawName) {
    final trimmed = rawName?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : 'Owner';
  }

  static String normalizeBusinessName(String? rawName) {
    final trimmed = rawName?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : 'My Shop';
  }

  // OTP is intentionally disabled for the current MVP.
  // The RPC requires auth.uid(), so create an anonymous Supabase session first.
  static Future<void> _ensureAuthenticatedSession() async {
    if (currentUser != null) {
      return;
    }

    try {
      final response = await _client.auth.signInAnonymously();

      if (response.user == null) {
        throw Exception('Anonymous authentication failed.');
      }
    } on AuthException catch (e) {
      throw Exception('Authentication failed: ${e.message}');
    } catch (e) {
      throw Exception('Authentication failed: $e');
    }
  }

  static Future<UserProfile> loginWithApprovedPhone(String phone) async {
    final normalizedPhone = normalizeIndianPhone(phone);

    if (normalizedPhone == null ||
        !isValidIndianPhone(normalizedPhone)) {
      throw Exception('Invalid phone number.');
    }

    await _ensureAuthenticatedSession();

    const rpcName = 'mvp_login_with_phone';

    try {
      final response = await _client.rpc(
        rpcName,
        params: {'p_phone': normalizedPhone},
      );

      if (response is List &&
          response.isNotEmpty &&
          response.first is Map<String, dynamic>) {
        return _mapProfile(
          Map<String, dynamic>.from(response.first as Map),
        );
      }

      throw Exception(
        'Login failed. The mobile number is not approved.',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'RPC error: rpc=$rpcName phone=$normalizedPhone '
        'code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
      );
      // Surface the exact backend message (set by mvp_login_with_phone's
      // RAISE EXCEPTION calls) so the UI can distinguish each failure case.
      throw Exception(e.message);
    } on AuthException catch (e) {
      debugPrint('Auth error: rpc=$rpcName phone=$normalizedPhone message=${e.message}');
      throw Exception('Authentication failed: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected login error: rpc=$rpcName phone=$normalizedPhone error=$e');
      throw Exception('Network or unexpected error: $e');
    }
  }

  static Future<void> signOut() async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.auth.signOut();
  }

  // Looks up the caller's own session profile row (id = auth.uid()).
  // mvp_login_with_phone keeps this row's role/name/default_business_id in
  // sync with the real profile on every login, so this satisfies the
  // `profiles_select_own` RLS policy (auth.uid() = id) directly. Do not
  // redirect through mvp_identity_links to the "real" profile id here --
  // that id is not auth.uid(), so the RLS-protected select would return
  // nothing and callers would see a null profile (e.g. missing businessId).
  static Future<UserProfile?> fetchProfileById(String userId) async {
    final client = _clientOrNull;
    if (client == null) return null;

    final row = await client
        .from('profiles')
        .select('id, phone, role, name, default_business_id')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    return _mapProfile(row);
  }

  static Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    return fetchProfileById(user.id);
  }

  static Future<UserProfile> upsertDefaultCustomerProfile({
    required String userId,
    required String phone,
  }) async {
    final client = _clientOrNull;

    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }

    final row = await client
        .from('profiles')
        .upsert(
          {
            'id': userId,
            'phone': phone,
            'role': 'customer',
          },
          onConflict: 'id',
        )
        .select('id, phone, role, name, default_business_id')
        .single();

    return _mapProfile(row);
  }

  static Future<UserProfile> ensureBusinessMembership({
    required String userId,
    required String phone,
    required String role,
    required String name,
    required String businessName,
  }) async {
    final client = _clientOrNull;

    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }

    final existingProfile = await fetchProfileById(userId);

    if (existingProfile != null) {
      return existingProfile;
    }

    final createdBusinessResponse = await client
        .from('businesses')
        .insert({
          'name': businessName,
          'owner_id': userId,
          'status': 'active',
          'currency': 'INR',
        })
        .select('id')
        .single();

    final businessId = createdBusinessResponse['id'] as String?;

    if (businessId == null) {
      throw Exception('Unable to create business for the new owner.');
    }

    final profileRow = await client
        .from('profiles')
        .upsert(
          {
            'id': userId,
            'phone': phone,
            'role': role,
            'name': name,
            'default_business_id': businessId,
          },
          onConflict: 'id',
        )
        .select('id, phone, role, name, default_business_id')
        .single();

    await client.from('business_members').insert({
      'business_id': businessId,
      'user_id': userId,
      'role': role == 'owner' ? 'owner' : 'customer',
      'status': 'active',
    });

    return _mapProfile(profileRow);
  }

  static UserProfile _mapProfile(Map<String, dynamic> row) {
    return UserProfile(
      id: row['id'] as String,
      phone: row['phone'] as String,
      role: (row['role'] as String?) ?? 'customer',
      name: row['name'] as String?,
      businessId: row['default_business_id'] as String?,
    );
  }

  static User? get currentUser {
    final client = _clientOrNull;
    return client?.auth.currentUser;
  }
}

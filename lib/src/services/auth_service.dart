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

  static Future<void> signInWithPhone(String phone) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.auth.signInWithOtp(phone: phone);
  }

  static Future<AuthResponse> verifyOtp({required String phone, required String token}) async {
    final client = _clientOrNull;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }
    return client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

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

  static Future<UserProfile> upsertDefaultCustomerProfile({required String userId, required String phone}) async {
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

  static Future<UserProfile> ensureBusinessMembership({required String userId, required String phone, required String role, required String name, required String businessName}) async {
    final client = _clientOrNull;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }

    final existingProfile = await fetchProfileById(userId);
    if (existingProfile != null) {
      return existingProfile;
    }

    final createdBusinessResponse = await client.from('businesses').insert({
      'name': businessName,
      'owner_id': userId,
      'status': 'active',
      'currency': 'INR',
    }).select('id').single();

    final businessId = createdBusinessResponse['id'] as String?;
    if (businessId == null) {
      throw Exception('Unable to create business for the new owner.');
    }

    final profileRow = await client.from('profiles').upsert({
      'id': userId,
      'phone': phone,
      'role': role,
      'name': name,
      'default_business_id': businessId,
    }, onConflict: 'id').select('id, phone, role, name, default_business_id').single();

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

import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getForCurrentUser(String businessId) async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return [];

    final response = await client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<void> markRead(String notificationId) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }
}

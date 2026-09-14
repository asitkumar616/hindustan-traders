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

  /// Unread count for the bell-icon badge -- deliberately a separate,
  /// lightweight query (not derived from [getForCurrentUser], which caps at
  /// 10 rows and is only fetched when the panel is opened) so the badge can
  /// be shown on screen load without the user having to open the panel
  /// first to discover something is waiting.
  static Future<int> getUnreadCount(String businessId) async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return 0;

    final response = await client
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('business_id', businessId)
        .eq('is_read', false);

    return (response as List).length;
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
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

  /// A customer's own orders across every business they shop with, newest
  /// first. Deliberately unjoined (no business/customer embed) so it only
  /// relies on the `orders_select_customer_or_business_member` RLS policy's
  /// `customer_id = auth.uid()` clause -- callers resolve business names
  /// client-side from data they already have (e.g. CustomerDashboardService).
  static Future<List<Map<String, dynamic>>> getRecentOrdersForCustomer({int limit = 5}) async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return [];

    final response = await client
        .from('orders')
        .select('id, business_id, status, total_amount, created_at')
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Full order history for the current customer across every business,
  /// including item counts (via `order_items`, same RLS-safe embed pattern
  /// as [getOrdersForBusiness], scoped by `orders.customer_id = auth.uid()`).
  static Future<List<Map<String, dynamic>>> getOrdersForCustomer() async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return [];

    final response = await client
        .from('orders')
        .select('id, business_id, status, total_amount, created_at, order_items(id)')
        .eq('customer_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<List<Map<String, dynamic>>> getOrdersForBusiness(String businessId) async {
    final client = _clientOrNull;
    if (client == null) return [];

    final response = await client
        .from('orders')
        .select('''
          id,
          business_id,
          customer_id,
          status,
          total_amount,
          created_at,
          customer:profiles!orders_customer_id_fkey(name, phone),
          order_items (
            id,
            product_id,
            quantity,
            unit,
            price,
            amount,
            product:products!order_items_product_id_fkey(name)
          )
        ''')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<void> updateStatus(
    String orderId,
    String status, {
    String? customerId,
    String? businessId,
  }) async {
    await _client.from('orders').update({'status': status}).eq('id', orderId);

    if (status == 'ready' && customerId != null && businessId != null) {
      await _client.from('notifications').insert({
        'recipient_id': customerId,
        'business_id': businessId,
        'title': 'Order packed',
        'body': 'Your order is packed and ready for delivery.',
        'data': {'order_id': orderId, 'status': status},
      });
    }
  }

  static String formatDisplayDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return '—';
    }

    try {
      final parsed = DateTime.parse(timestamp).toLocal();
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}

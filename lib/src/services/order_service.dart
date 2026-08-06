import 'package:flutter/material.dart';
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

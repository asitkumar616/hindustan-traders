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

  /// Line items for a single order, with product names -- used to build a
  /// printable receipt from the customer side. Relies on the
  /// `order_items_select_related` RLS policy (allowed when the caller is
  /// either the order's own customer or a member of its business).
  static Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final client = _clientOrNull;
    if (client == null) return [];

    final response = await client
        .from('order_items')
        .select(
          'id, product_id, quantity, unit, price, amount, '
          'variant_id, product_name, brand, variant_quantity, variant_unit, package_type, '
          'product:products!order_items_product_id_fkey(name)',
        )
        .eq('order_id', orderId);

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
            variant_id,
            product_name,
            brand,
            variant_quantity,
            variant_unit,
            package_type,
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

    if (customerId == null || businessId == null) return;

    final notification = switch (status) {
      'ready' => ('Order packed', 'Your order is packed and ready for delivery.'),
      'completed' => ('Order completed', 'Your order has been marked complete.'),
      'cancelled' => ('Order declined', 'Your order was declined by the shop. Please contact them for details.'),
      _ => null,
    };
    if (notification == null) return;

    await _client.from('notifications').insert({
      'recipient_id': customerId,
      'business_id': businessId,
      'title': notification.$1,
      'body': notification.$2,
      'data': {'order_id': orderId, 'status': status},
    });
  }

  /// Product name for one order_item -- prefers the snapshot taken at order
  /// time (survives the product being renamed/deleted later) and falls back
  /// to the live joined product name for pre-migration rows that predate
  /// the snapshot columns.
  static String itemProductName(Map<String, dynamic> item) {
    final snapshot = item['product_name']?.toString();
    if (snapshot != null && snapshot.isNotEmpty) return snapshot;
    final product = item['product'] as Map<String, dynamic>?;
    return product?['name']?.toString() ?? 'Product';
  }

  /// "50 × 25 KG BAG" style quantity label for one order_item -- built from
  /// the variant snapshot when present, otherwise falls back to the legacy
  /// flat quantity/unit for orders placed before variants existed.
  static String itemQuantityLabel(Map<String, dynamic> item) {
    final orderedQty = item['quantity'];
    final variantQuantity = (item['variant_quantity'] as num?)?.toDouble();
    final variantUnit = item['variant_unit']?.toString();

    if (variantQuantity != null && variantUnit != null && variantUnit.isNotEmpty) {
      final packageType = item['package_type']?.toString();
      final qtyStr = variantQuantity == variantQuantity.roundToDouble()
          ? variantQuantity.toInt().toString()
          : variantQuantity.toString();
      final variantLabel = (packageType == null || packageType.isEmpty || packageType == 'LOOSE')
          ? '$qtyStr $variantUnit'
          : '$qtyStr $variantUnit $packageType';
      return '$orderedQty × $variantLabel';
    }

    final unit = item['unit']?.toString() ?? '';
    return '$orderedQty $unit';
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

import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerBusiness {
  final String businessId;
  final String businessName;
  final String businessStatus;
  final String customerId;
  final String? customerDisplayName;

  const CustomerBusiness({
    required this.businessId,
    required this.businessName,
    required this.businessStatus,
    required this.customerId,
    required this.customerDisplayName,
  });
}

class CustomerDashboardSummary {
  final int totalOrders;
  final double totalSpent;
  final int todayOrders;
  final double todaySpent;
  final double totalBalance;

  const CustomerDashboardSummary({
    required this.totalOrders,
    required this.totalSpent,
    required this.todayOrders,
    required this.todaySpent,
    required this.totalBalance,
  });

  static const empty = CustomerDashboardSummary(
    totalOrders: 0,
    totalSpent: 0,
    todayOrders: 0,
    todaySpent: 0,
    totalBalance: 0,
  );
}

class CustomerDashboardService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<CustomerDashboardSummary> fetchSummary() async {
    final client = _clientOrNull;
    if (client == null) return CustomerDashboardSummary.empty;

    try {
      final response = await client.rpc('customer_dashboard_summary');
      final rows = response is List ? response : <dynamic>[];
      if (rows.isEmpty) return CustomerDashboardSummary.empty;

      final row = Map<String, dynamic>.from((rows.first as Map).cast<String, dynamic>());
      return CustomerDashboardSummary(
        totalOrders: _asInt(row['total_orders']),
        totalSpent: _asDouble(row['total_spent']),
        todayOrders: _asInt(row['today_orders']),
        todaySpent: _asDouble(row['today_spent']),
        totalBalance: _asDouble(row['total_balance']),
      );
    } catch (_) {
      return CustomerDashboardSummary.empty;
    }
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<List<CustomerBusiness>> fetchMyBusinesses() async {
    final client = _clientOrNull;
    if (client == null) return const <CustomerBusiness>[];

    final response = await client.rpc('customer_my_businesses');
    final rows = response is List ? response : <dynamic>[];

    return rows
        .whereType<Map>()
        .map((row) {
          final data = Map<String, dynamic>.from(row.cast<String, dynamic>());
          return CustomerBusiness(
            businessId: data['business_id']?.toString() ?? '',
            businessName: data['business_name']?.toString() ?? 'Shop',
            businessStatus: data['business_status']?.toString() ?? 'active',
            customerId: data['customer_id']?.toString() ?? '',
            customerDisplayName: data['customer_display_name']?.toString(),
          );
        })
        .where((row) => row.businessId.isNotEmpty)
        .toList(growable: false);
  }

  /// Top products from the customer's own order history, ranked by how many
  /// separate orders included them. Retains business_id (an order only ever
  /// belongs to one business, so every item does too) and refreshes each
  /// with its CURRENT variant price/active-state -- never the historical
  /// price the item was originally ordered at. A product whose variant is
  /// no longer active is dropped rather than shown as orderable.
  static Future<List<Map<String, dynamic>>> getFrequentlyOrderedProducts({int limit = 4}) async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return [];

    final orderRows = await client
        .from('orders')
        .select('id, business_id')
        .eq('customer_id', userId)
        .neq('status', 'cancelled');
    final orders = List<Map<String, dynamic>>.from(orderRows as List);
    if (orders.isEmpty) return [];

    final businessByOrder = <String, String>{
      for (final order in orders) order['id'].toString(): order['business_id']?.toString() ?? '',
    };
    final orderIds = businessByOrder.keys.toList();

    final itemRows = await client
        .from('order_items')
        .select('order_id, product_id, variant_id, product_name, brand, variant_quantity, variant_unit, package_type')
        .inFilter('order_id', orderIds);
    final items = List<Map<String, dynamic>>.from(itemRows as List);

    final counts = <String, int>{};
    final samples = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final productId = item['product_id']?.toString();
      if (productId == null || productId.isEmpty) continue;
      counts[productId] = (counts[productId] ?? 0) + 1;
      samples.putIfAbsent(productId, () => {
            ...item,
            'business_id': businessByOrder[item['order_id']?.toString()] ?? '',
          });
    }
    if (counts.isEmpty) return [];

    final ranked = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final variantIds = ranked
        .map((productId) => samples[productId]?['variant_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final variantRows = variantIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
            .from('product_variants')
            .select('id, selling_price, is_active, minimum_order_quantity')
            .inFilter('id', variantIds);
    final variantById = <String, Map<String, dynamic>>{
      for (final variant in variantRows) variant['id'].toString(): variant,
    };

    final result = <Map<String, dynamic>>[];
    for (final productId in ranked) {
      if (result.length >= limit) break;
      final sample = samples[productId]!;
      final variantId = sample['variant_id']?.toString();
      final variant = variantId != null ? variantById[variantId] : null;
      if (variant == null || variant['is_active'] == false) continue;
      result.add({
        ...sample,
        'current_price': (variant['selling_price'] as num?) ?? 0,
        'minimum_order_quantity': (variant['minimum_order_quantity'] as num?) ?? 1,
        'order_count': counts[productId],
      });
    }
    return result;
  }

  /// Distinct product categories across the given businesses' active
  /// catalogs -- used for the dashboard's "Shop by Category" shortcuts,
  /// which need a cross-shop category list before any single shop is
  /// chosen. Categories are free text set by each owner (no categories
  /// table), so this reads the live set rather than a hardcoded list.
  static Future<List<String>> getCategoriesForBusinesses(List<String> businessIds) async {
    final client = _clientOrNull;
    if (client == null || businessIds.isEmpty) return [];

    final rows = await client
        .from('products')
        .select('category')
        .inFilter('business_id', businessIds)
        .eq('is_active', true)
        .not('category', 'is', null);

    final categories = List<Map<String, dynamic>>.from(rows as List)
        .map((row) => row['category']?.toString() ?? '')
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }
}

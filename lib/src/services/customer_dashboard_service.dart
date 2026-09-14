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
}

import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerDashboardSummary {
  final String businessId;
  final String businessName;
  final int totalCustomers;
  final int todayOrders;
  final double todayRevenue;
  final double pendingAmount;

  const OwnerDashboardSummary({
    required this.businessId,
    required this.businessName,
    required this.totalCustomers,
    required this.todayOrders,
    required this.todayRevenue,
    required this.pendingAmount,
  });

  static const empty = OwnerDashboardSummary(
    businessId: '',
    businessName: '',
    totalCustomers: 0,
    todayOrders: 0,
    todayRevenue: 0,
    pendingAmount: 0,
  );
}

class OwnerCustomerBalance {
  final String customerId;
  final String displayName;
  final String? phone;
  final String status;
  final bool isActive;
  final double outstandingAmount;
  final DateTime? lastOrderAt;

  const OwnerCustomerBalance({
    required this.customerId,
    required this.displayName,
    required this.phone,
    required this.status,
    required this.isActive,
    required this.outstandingAmount,
    required this.lastOrderAt,
  });
}

class OwnerDashboardService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<OwnerDashboardSummary> fetchSummary() async {
    final client = _clientOrNull;
    if (client == null) return OwnerDashboardSummary.empty;

    final response = await client.rpc('owner_dashboard_summary');
    final row = _firstRow(response);
    if (row.isEmpty) return OwnerDashboardSummary.empty;

    return OwnerDashboardSummary(
      businessId: row['business_id']?.toString() ?? '',
      businessName: row['business_name']?.toString() ?? '',
      totalCustomers: _asInt(row['total_customers']),
      todayOrders: _asInt(row['today_orders']),
      todayRevenue: _asDouble(row['today_revenue']),
      pendingAmount: _asDouble(row['pending_amount']),
    );
  }

  static Future<List<OwnerCustomerBalance>> fetchCustomerBalances({bool onlyOutstanding = false}) async {
    final client = _clientOrNull;
    if (client == null) return const <OwnerCustomerBalance>[];

    final response = await client.rpc('owner_customer_balances', params: {
      'p_only_outstanding': onlyOutstanding,
    });
    final rows = response is List ? response : <dynamic>[];

    return rows
        .whereType<Map>()
        .map((row) {
          final data = Map<String, dynamic>.from(row.cast<String, dynamic>());
          final lastOrderRaw = data['last_order_at']?.toString();
          return OwnerCustomerBalance(
            customerId: data['customer_id']?.toString() ?? '',
            displayName: data['display_name']?.toString() ?? 'Customer',
            phone: data['phone']?.toString(),
            status: data['status']?.toString() ?? 'NOT_REGISTERED',
            isActive: data['is_active'] == true,
            outstandingAmount: _asDouble(data['outstanding_amount']),
            lastOrderAt: lastOrderRaw != null ? DateTime.tryParse(lastOrderRaw) : null,
          );
        })
        .where((row) => row.customerId.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic> _firstRow(dynamic response) {
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return <String, dynamic>{};
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
}

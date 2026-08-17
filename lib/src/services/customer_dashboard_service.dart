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

class CustomerDashboardService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
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

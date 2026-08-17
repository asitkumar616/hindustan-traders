import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AdminDashboardSummary {
  final int totalOwners;
  final int totalBusinesses;
  final int totalCustomers;
  final int activeCustomers;

  const AdminDashboardSummary({
    required this.totalOwners,
    required this.totalBusinesses,
    required this.totalCustomers,
    required this.activeCustomers,
  });
}

class AdminOwnerSummary {
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final int businessCount;
  final int customerCount;

  const AdminOwnerSummary({
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.businessCount,
    required this.customerCount,
  });
}

class AdminOwnerRecord {
  final String profileId;
  final String ownerName;
  final String ownerPhone;
  final String businessId;
  final String businessName;
  final String? businessAddress;
  final String approvalStatus;
  final bool isActive;
  final int customerCount;

  const AdminOwnerRecord({
    required this.profileId,
    required this.ownerName,
    required this.ownerPhone,
    required this.businessId,
    required this.businessName,
    required this.businessAddress,
    required this.approvalStatus,
    required this.isActive,
    required this.customerCount,
  });
}

class AdminBusinessRecord {
  final String businessId;
  final String businessName;
  final String? businessAddress;
  final String businessStatus;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final int customerCount;

  const AdminBusinessRecord({
    required this.businessId,
    required this.businessName,
    required this.businessAddress,
    required this.businessStatus,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.customerCount,
  });
}

class AdminCustomerRecord {
  final String customerId;
  final String businessId;
  final String businessName;
  final String displayName;
  final String? customerName;
  final String? shopName;
  final String? phone;
  final String status;
  final bool isActive;

  const AdminCustomerRecord({
    required this.customerId,
    required this.businessId,
    required this.businessName,
    required this.displayName,
    required this.customerName,
    required this.shopName,
    required this.phone,
    required this.status,
    required this.isActive,
  });
}

class AdminDashboardService {
  static SupabaseClient? get _clientOrNull {
    if (!SupabaseService.isInitialized) {
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get backendReady => _clientOrNull != null;

  static Future<AdminDashboardSummary> fetchSummary() async {
    final client = _clientOrNull;
    if (client == null) {
      return const AdminDashboardSummary(
        totalOwners: 0,
        totalBusinesses: 0,
        totalCustomers: 0,
        activeCustomers: 0,
      );
    }

    try {
      final response = await client.rpc('admin_dashboard_summary');
      final row = _firstRow(response);
      return AdminDashboardSummary(
        totalOwners: _asInt(row['total_owners']),
        totalBusinesses: _asInt(row['total_businesses']),
        totalCustomers: _asInt(row['total_customers']),
        activeCustomers: _asInt(row['active_customers']),
      );
    } catch (_) {
      return const AdminDashboardSummary(
        totalOwners: 0,
        totalBusinesses: 0,
        totalCustomers: 0,
        activeCustomers: 0,
      );
    }
  }

  static Future<List<AdminOwnerSummary>> fetchOwners() async {
    final client = _clientOrNull;
    if (client == null) {
      return const <AdminOwnerSummary>[];
    }

    try {
      final response = await client.rpc('admin_owner_customer_breakdown');
      final rows = response is List ? response : <dynamic>[];
      return rows
          .whereType<Map>()
          .map((row) {
            final data = Map<String, dynamic>.from(row.cast<String, dynamic>());
            return AdminOwnerSummary(
              ownerId: data['owner_id']?.toString() ?? '',
              ownerName: data['owner_name']?.toString() ?? 'Owner',
              ownerPhone: data['owner_phone']?.toString() ?? '',
              businessCount: _asInt(data['business_count']),
              customerCount: _asInt(data['customer_count']),
            );
          })
          .where((owner) => owner.ownerId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <AdminOwnerSummary>[];
    }
  }

  static Future<List<AdminOwnerRecord>> listOwners({String? query}) async {
    final client = _clientOrNull;
    if (client == null) return const <AdminOwnerRecord>[];

    final response = await client.rpc('admin_owner_list', params: {'p_query': query});
    final rows = response is List ? response : <dynamic>[];

    return rows
        .whereType<Map>()
        .map((row) {
          final data = Map<String, dynamic>.from(row.cast<String, dynamic>());
          return AdminOwnerRecord(
            profileId: data['profile_id']?.toString() ?? '',
            ownerName: data['owner_name']?.toString() ?? 'Owner',
            ownerPhone: data['owner_phone']?.toString() ?? '',
            businessId: data['business_id']?.toString() ?? '',
            businessName: data['business_name']?.toString() ?? '',
            businessAddress: data['business_address']?.toString(),
            approvalStatus: data['approval_status']?.toString() ?? 'pending',
            isActive: data['is_active'] == true,
            customerCount: _asInt(data['customer_count']),
          );
        })
        .where((row) => row.profileId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<AdminBusinessRecord>> listBusinesses({String? query}) async {
    final client = _clientOrNull;
    if (client == null) return const <AdminBusinessRecord>[];

    final response = await client.rpc('admin_business_list', params: {'p_query': query});
    final rows = response is List ? response : <dynamic>[];

    return rows
        .whereType<Map>()
        .map((row) {
          final data = Map<String, dynamic>.from(row.cast<String, dynamic>());
          return AdminBusinessRecord(
            businessId: data['business_id']?.toString() ?? '',
            businessName: data['business_name']?.toString() ?? '',
            businessAddress: data['business_address']?.toString(),
            businessStatus: data['business_status']?.toString() ?? 'inactive',
            ownerId: data['owner_id']?.toString() ?? '',
            ownerName: data['owner_name']?.toString() ?? 'Owner',
            ownerPhone: data['owner_phone']?.toString() ?? '',
            customerCount: _asInt(data['customer_count']),
          );
        })
        .where((row) => row.businessId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<AdminCustomerRecord>> listCustomers({String? query, bool activeOnly = false}) async {
    final client = _clientOrNull;
    if (client == null) return const <AdminCustomerRecord>[];

    final response = await client.rpc('admin_customer_list', params: {
      'p_query': query,
      'p_active_only': activeOnly,
    });
    final rows = response is List ? response : <dynamic>[];

    return rows
        .whereType<Map>()
        .map((row) {
          final data = Map<String, dynamic>.from(row.cast<String, dynamic>());
          return AdminCustomerRecord(
            customerId: data['customer_id']?.toString() ?? '',
            businessId: data['business_id']?.toString() ?? '',
            businessName: data['business_name']?.toString() ?? '',
            displayName: data['display_name']?.toString() ?? 'Customer',
            customerName: data['customer_name']?.toString(),
            shopName: data['shop_name']?.toString(),
            phone: data['phone']?.toString(),
            status: data['status']?.toString() ?? 'NOT_REGISTERED',
            isActive: data['is_active'] == true,
          );
        })
        .where((row) => row.customerId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> createOwner({
    required String ownerName,
    required String phone,
    required String businessName,
    String? address,
    String status = 'pending',
  }) async {
    final client = _clientOrNull;
    if (client == null) {
      throw Exception('Backend is not ready.');
    }

    await client.rpc('admin_owner_create', params: {
      'p_owner_name': ownerName,
      'p_phone': phone,
      'p_business_name': businessName,
      'p_business_address': address,
      'p_status': status,
    });
  }

  static Future<void> updateOwner({
    required String profileId,
    required String ownerName,
    required String phone,
    required String businessName,
    String? address,
  }) async {
    final client = _clientOrNull;
    if (client == null) {
      throw Exception('Backend is not ready.');
    }

    await client.rpc('admin_owner_update', params: {
      'p_profile_id': profileId,
      'p_owner_name': ownerName,
      'p_phone': phone,
      'p_business_name': businessName,
      'p_business_address': address,
    });
  }

  static Future<void> setOwnerState({
    required String profileId,
    required String status,
    required bool isActive,
  }) async {
    final client = _clientOrNull;
    if (client == null) {
      throw Exception('Backend is not ready.');
    }

    await client.rpc('admin_owner_set_state', params: {
      'p_profile_id': profileId,
      'p_status': status,
      'p_is_active': isActive,
    });
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
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
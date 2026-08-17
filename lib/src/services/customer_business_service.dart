import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class CustomerBusinessService {
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

  static Future<List<Map<String, dynamic>>> getCustomersForBusiness(String businessId) async {
    final client = _clientOrNull;
    if (client == null) return [];

    final response = await client
        .from('customers')
        .select('id, business_id, profile_id, display_name, phone, is_active, status, shop_name, created_at')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<Map<String, dynamic>?> createCustomerRecord({
    required String businessId,
    required String phone,
    required String customerName,
    required String shopName,
    required String address,
    required double openingBalance,
  }) async {
    final normalizedPhone = AuthService.normalizeIndianPhone(phone) ?? phone.trim();
    final payload = {
      'business_id': businessId,
      'phone': normalizedPhone,
      'display_name': customerName.trim().isEmpty ? shopName.trim() : customerName.trim(),
      'customer_name': customerName.trim(),
      'shop_name': shopName.trim(),
      'address': address.trim(),
      'opening_balance': openingBalance,
      'status': 'NOT_REGISTERED',
      'profile_id': null,
      'is_active': false,
    };

    final client = _clientOrNull;
    if (client == null) return null;

    final existing = await client
        .from('customers')
        .select('id')
        .eq('business_id', businessId)
        .eq('phone', normalizedPhone)
        .maybeSingle();

    Map<String, dynamic> record;
    if (existing != null) {
      record = await client
          .from('customers')
          .update(payload)
          .eq('id', existing['id'])
          .select('id, business_id, profile_id, display_name, phone, status, shop_name, created_at')
          .single();
    } else {
      record = await client
          .from('customers')
          .insert(payload)
          .select('id, business_id, profile_id, display_name, phone, status, shop_name, created_at')
          .single();
    }

    // Link this customer to the business immediately (not only at their
    // first login), so a customer already linked to another owner's
    // business becomes associated with this one too, without creating a
    // duplicate customer person -- this is the same customer_businesses
    // relationship mvp_login_with_phone keeps in sync on every login.
    await client.from('customer_businesses').upsert(
      {
        'customer_id': record['id'],
        'business_id': businessId,
        'status': 'ACTIVE',
      },
      onConflict: 'customer_id,business_id',
    );

    return record;
  }

  static Future<Map<String, dynamic>?> findCustomerByPhone(String phone) async {
    final normalizedPhone = AuthService.normalizeIndianPhone(phone) ?? phone.trim();
    final client = _clientOrNull;
    if (client == null) return null;

    final response = await client
        .from('customers')
        .select('id, business_id, profile_id, display_name, customer_name, shop_name, phone, status, created_at')
        .eq('phone', normalizedPhone)
        .maybeSingle();

    return response;
  }

  static Future<List<Map<String, dynamic>>> getProductsForBusiness(String businessId) async {
    final client = _clientOrNull;
    if (client == null) return [];

    final response = await client
        .from('products')
        .select('''
          id,
          name,
          unit,
          product_prices(price, valid_from)
        ''')
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from((response as List).map((row) => normalizeProductRow(row as Map<String, dynamic>)));
  }

  static Map<String, dynamic> buildProductPayload({
    required String businessId,
    required String name,
    required String unit,
    bool isActive = true,
  }) {
    return {
      'business_id': businessId,
      'name': name.trim(),
      'unit': unit.trim().isEmpty ? 'unit' : unit.trim(),
      'is_active': isActive,
    };
  }

  static Map<String, dynamic> buildPricePayload({required String productId, required double price}) {
    return {
      'product_id': productId,
      'price': price,
    };
  }

  static Future<Map<String, dynamic>?> createProduct({
    required String businessId,
    required String name,
    required String unit,
    required double price,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Product name is required');
    }

    final client = _clientOrNull;
    if (client == null) return null;

    final createdProduct = await client
        .from('products')
        .insert(buildProductPayload(businessId: businessId, name: trimmedName, unit: unit))
        .select('id, name, unit')
        .single();

    final productId = createdProduct['id'] as String?;
    if (productId != null) {
      await client.from('product_prices').insert(buildPricePayload(productId: productId, price: price));
    }

    return createdProduct;
  }

  static Future<void> updateProduct({
    required String productId,
    String? name,
    String? unit,
    double? price,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;

    final updates = <String, dynamic>{};
    if (name != null) {
      updates['name'] = name.trim();
    }
    if (unit != null) {
      updates['unit'] = unit.trim().isEmpty ? 'unit' : unit.trim();
    }

    if (updates.isNotEmpty) {
      await client.from('products').update(updates).eq('id', productId);
    }

    if (price != null) {
      await client.from('product_prices').insert(buildPricePayload(productId: productId, price: price));
    }
  }

  static Future<void> deleteProduct({required String productId}) async {
    final client = _clientOrNull;
    if (client == null) return;

    await client.from('products').update({'is_active': false}).eq('id', productId);
  }

  static Future<Map<String, dynamic>?> createInvoiceDraft({
    required String businessId,
    required String customerId,
    required String orderId,
    required double totalAmount,
  }) async {
    final client = _clientOrNull;
    if (client == null) return null;

    final response = await client.from('invoices').insert({
      'business_id': businessId,
      'customer_id': customerId,
      'order_id': orderId,
      'invoice_number': 'INV-${DateTime.now().millisecondsSinceEpoch}',
      'status': 'draft',
      'subtotal': totalAmount,
      'discount': 0,
      'total': totalAmount,
      'paid_amount': 0,
      'balance_amount': totalAmount,
    }).select('id, invoice_number, total').single();

    return response is Map<String, dynamic> ? response : null;
  }

  static Map<String, dynamic> normalizeProductRow(Map<String, dynamic> row) {
    final prices = (row['product_prices'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    num latestPrice = 0;
    if (prices.isNotEmpty) {
      latestPrice = prices.last['price'] as num? ?? 0;
    }

    return {
      'id': row['id'],
      'name': row['name'],
      'unit': row['unit'],
      'price': latestPrice,
    };
  }

  static Future<UserProfile?> linkCustomerAfterOtp({
    required String phone,
    required String userId,
    required String? displayName,
  }) async {
    final normalizedPhone = AuthService.normalizeIndianPhone(phone) ?? phone.trim();
    final client = _clientOrNull;
    if (client == null) return null;

    final customer = await client
        .from('customers')
        .select('id, business_id, profile_id, display_name, customer_name, shop_name, phone, status')
        .eq('phone', normalizedPhone)
        .maybeSingle();

    if (customer == null) {
      return null;
    }

    final resolvedName = (displayName ?? customer['customer_name'] ?? customer['display_name'] ?? 'Customer').toString().trim();
    final businessId = customer['business_id'] as String?;
    if (businessId == null || businessId.isEmpty) {
      return null;
    }

    final existingProfile = await client
        .from('profiles')
        .select('role, default_business_id')
        .eq('id', userId)
        .maybeSingle();

    final profilePayload = {
      'id': userId,
      'phone': normalizedPhone,
      'role': (existingProfile?['role'] as String?) ?? 'customer',
      'name': resolvedName,
      'default_business_id': (existingProfile?['default_business_id'] as String?) ?? businessId,
    };

    final profileRow = await client
        .from('profiles')
        .upsert(profilePayload, onConflict: 'id')
        .select('id, phone, role, name, default_business_id')
        .single();

    await client.from('business_members').upsert({
      'business_id': businessId,
      'user_id': userId,
      'role': 'customer',
      'status': 'active',
    }, onConflict: 'business_id,user_id');

    await client.from('customer_businesses').upsert({
      'customer_id': customer['id'],
      'business_id': businessId,
      'status': 'ACTIVE',
    }, onConflict: 'customer_id,business_id');

    await client.from('customers').update({
      'profile_id': userId,
      'status': 'ACTIVE',
      'is_active': true,
      'display_name': resolvedName,
    }).eq('id', customer['id']);

    return UserProfile(
      id: profileRow['id'] as String,
      phone: profileRow['phone'] as String,
      role: (profileRow['role'] as String?) ?? 'customer',
      name: profileRow['name'] as String?,
      businessId: profileRow['default_business_id'] as String?,
    );
  }
}

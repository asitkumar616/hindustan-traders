import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/master_product.dart';
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
    bool isActive = true,
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
      'status': isActive ? 'NOT_REGISTERED' : 'BLOCKED',
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

  static Future<Map<String, dynamic>?> getCustomerById(String customerId) async {
    final client = _clientOrNull;
    if (client == null) return null;

    return await client
        .from('customers')
        .select('id, business_id, profile_id, display_name, customer_name, shop_name, phone, address, opening_balance, credit_limit, status, is_active, created_at')
        .eq('id', customerId)
        .maybeSingle();
  }

  static Future<void> setCustomerBlocked(
    String customerId,
    bool blocked, {
    required bool isRegistered,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;

    final status = blocked ? 'BLOCKED' : (isRegistered ? 'ACTIVE' : 'NOT_REGISTERED');
    await client.from('customers').update({'status': status}).eq('id', customerId);
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
          category,
          brand,
          image_url,
          master_product_id,
          product_variants(id, quantity, unit, package_type, selling_price, minimum_order_quantity, stock_quantity, is_active)
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
    String? category,
    String? brand,
    String? imageUrl,
    String? masterProductId,
    bool isActive = true,
  }) {
    return {
      'business_id': businessId,
      'name': name.trim(),
      'unit': unit.trim().isEmpty ? 'unit' : unit.trim(),
      'category': category,
      'brand': brand,
      'image_url': imageUrl,
      'master_product_id': masterProductId,
      'is_active': isActive,
    };
  }

  /// Creates the owner's product row and a single LOOSE variant for it --
  /// kept for the existing "Speak to add product" voice flow
  /// (voice_product_result_screen.dart), which only ever collects one
  /// name/unit/price. Manual product setup now goes through
  /// createProductFromMasterProduct / createCustomProduct + addVariant,
  /// which support multiple variants per product.
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
      await addVariant(
        productId: productId,
        quantity: 1,
        unit: _normalizeUnit(unit),
        packageType: 'LOOSE',
        sellingPrice: price,
      );
    }

    return createdProduct;
  }

  /// Updates the product's own fields and/or its single default variant --
  /// kept for the voice-add flow's edit path. Multi-variant products should
  /// use updateVariant directly instead.
  static Future<void> updateProduct({
    required String productId,
    required String businessId,
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
      final existingVariant = await client
          .from('product_variants')
          .select('id')
          .eq('product_id', productId)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (existingVariant != null) {
        await client.from('product_variants').update({'selling_price': price}).eq('id', existingVariant['id']);
      } else {
        await addVariant(
          productId: productId,
          quantity: 1,
          unit: _normalizeUnit(unit ?? 'KG'),
          packageType: 'LOOSE',
          sellingPrice: price,
        );
      }

      await _notifyCustomersOfPriceChange(
        businessId: businessId,
        productName: name?.trim().isNotEmpty == true ? name!.trim() : 'A product',
        newPrice: price,
        unit: unit,
      );
    }
  }

  static String _normalizeUnit(String rawUnit) {
    final upper = rawUnit.trim().toUpperCase();
    switch (upper) {
      case 'LITRE':
      case 'LITER':
        return 'LTR';
      case 'PIECE':
      case 'PIECES':
        return 'PCS';
      default:
        return kVariantUnits.contains(upper) ? upper : 'KG';
    }
  }

  // ----------------------------------------------------------------
  // Master catalog
  // ----------------------------------------------------------------

  static Future<List<MasterProduct>> getMasterProducts({String? category, String? query}) async {
    final client = _clientOrNull;
    if (client == null) return [];

    var builder = client.from('master_products').select().eq('is_active', true);
    if (category != null && category.isNotEmpty && category != 'Others') {
      builder = builder.eq('category', category);
    }
    if (query != null && query.trim().isNotEmpty) {
      builder = builder.ilike('product_name', '%${query.trim()}%');
    }

    final response = await builder.order('product_name', ascending: true);
    return (response as List).map((row) => MasterProduct.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// Links an owner's shop to a shared catalog entry -- creates the owner's
  /// own `products` row (business-scoped, per the multi-tenant model) with
  /// master_product_id set for traceability, copying display fields from
  /// the catalog entry as a starting point.
  /// [brandOverride] and [customName] let the same catalog entry (e.g. the
  /// generic "Rice" master product) be added multiple times under different
  /// brands -- "Kohinoor Rice", "India Gate Rice", etc. -- as separate
  /// `products` rows, each linked back to the same master_product_id. This
  /// is deliberately allowed to repeat: nothing here checks for an existing
  /// product with the same master_product_id, since one owner may
  /// legitimately stock several brands of the same generic item.
  static Future<Map<String, dynamic>?> createProductFromMasterProduct({
    required String businessId,
    required MasterProduct masterProduct,
    String? customName,
    String? brandOverride,
  }) async {
    final client = _clientOrNull;
    if (client == null) return null;

    final createdProduct = await client
        .from('products')
        .insert(buildProductPayload(
          businessId: businessId,
          name: customName?.trim().isNotEmpty == true ? customName!.trim() : masterProduct.productName,
          unit: masterProduct.baseUnit,
          category: masterProduct.category,
          brand: brandOverride?.trim().isNotEmpty == true ? brandOverride!.trim() : masterProduct.brand,
          imageUrl: masterProduct.imageUrl,
          masterProductId: masterProduct.id,
        ))
        .select('id, name, unit, category, brand, image_url, master_product_id')
        .single();

    return createdProduct;
  }

  static Future<Map<String, dynamic>?> createCustomProduct({
    required String businessId,
    required String name,
    required String baseUnit,
    String? category,
    String? brand,
    String? imageUrl,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Product name is required');
    }

    final client = _clientOrNull;
    if (client == null) return null;

    final createdProduct = await client
        .from('products')
        .insert(buildProductPayload(
          businessId: businessId,
          name: trimmedName,
          unit: baseUnit,
          category: category,
          brand: brand,
          imageUrl: imageUrl,
        ))
        .select('id, name, unit, category, brand, image_url, master_product_id')
        .single();

    return createdProduct;
  }

  // ----------------------------------------------------------------
  // Selling variants
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> addVariant({
    required String productId,
    required double quantity,
    required String unit,
    required String packageType,
    required double sellingPrice,
    double minimumOrderQuantity = 1,
    double? stockQuantity,
    bool isActive = true,
  }) async {
    final client = _clientOrNull;
    if (client == null) return null;

    return await client.from('product_variants').insert({
      'product_id': productId,
      'quantity': quantity,
      'unit': unit,
      'package_type': packageType,
      'selling_price': sellingPrice,
      'minimum_order_quantity': minimumOrderQuantity,
      'stock_quantity': stockQuantity,
      'is_active': isActive,
    }).select().single();
  }

  /// Updates a single variant's fields. If [notifyBusinessId] is given and
  /// the price changed, broadcasts a price-change notification the same way
  /// the old flat updateProduct did.
  static Future<void> updateVariant({
    required String variantId,
    double? quantity,
    String? unit,
    String? packageType,
    double? sellingPrice,
    double? minimumOrderQuantity,
    double? stockQuantity,
    bool? isActive,
    String? notifyBusinessId,
    String? notifyProductName,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;

    final updates = <String, dynamic>{};
    if (quantity != null) updates['quantity'] = quantity;
    if (unit != null) updates['unit'] = unit;
    if (packageType != null) updates['package_type'] = packageType;
    if (sellingPrice != null) updates['selling_price'] = sellingPrice;
    if (minimumOrderQuantity != null) updates['minimum_order_quantity'] = minimumOrderQuantity;
    if (stockQuantity != null) updates['stock_quantity'] = stockQuantity;
    if (isActive != null) updates['is_active'] = isActive;

    if (updates.isEmpty) return;

    await client.from('product_variants').update(updates).eq('id', variantId);

    if (sellingPrice != null && notifyBusinessId != null) {
      await _notifyCustomersOfPriceChange(
        businessId: notifyBusinessId,
        productName: notifyProductName ?? 'A product',
        newPrice: sellingPrice,
        unit: unit,
      );
    }
  }

  static Future<void> setVariantActive(String variantId, bool isActive) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.from('product_variants').update({'is_active': isActive}).eq('id', variantId);
  }

  static Future<void> deleteVariant(String variantId) async {
    await setVariantActive(variantId, false);
  }

  // Broadcasts a price change to every registered customer of this
  // business. Non-fatal by design: the price itself is already saved by
  // the time this runs, so a failure here (e.g. no registered customers,
  // or an RLS restriction) must not surface as a failed product update.
  static Future<void> _notifyCustomersOfPriceChange({
    required String businessId,
    required String productName,
    required double newPrice,
    String? unit,
  }) async {
    try {
      final client = _clientOrNull;
      if (client == null) return;

      final rows = await client
          .from('customers')
          .select('profile_id')
          .eq('business_id', businessId)
          .not('profile_id', 'is', null);

      final recipientIds = (rows as List)
          .map((row) => (row as Map)['profile_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (recipientIds.isEmpty) return;

      final unitLabel = unit?.trim().isNotEmpty == true ? '/${unit!.trim()}' : '';

      await client.from('notifications').insert(
        recipientIds
            .map((recipientId) => {
                  'recipient_id': recipientId,
                  'business_id': businessId,
                  'title': 'Price updated',
                  'body': '$productName is now ₹${newPrice.toStringAsFixed(0)}$unitLabel.',
                  'data': {'product_name': productName, 'new_price': newPrice},
                })
            .toList(),
      );
    } catch (_) {
      // Non-fatal -- see comment above.
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

  /// Shapes a `products` row (with its embedded `product_variants`) into the
  /// Map shape screens work with: keeps the existing flat `id/name/unit`
  /// keys other callers already rely on, adds `variants` (only the active
  /// ones, cheapest first) for variant-aware screens, and a `price` fallback
  /// (cheapest active variant) so any code not yet updated for variants
  /// still has a sane single price to show instead of crashing.
  static Map<String, dynamic> normalizeProductRow(Map<String, dynamic> row) {
    final variants = (row['product_variants'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where((variant) => variant['is_active'] != false)
        .toList()
      ..sort((a, b) => ((a['selling_price'] as num?) ?? 0).compareTo((b['selling_price'] as num?) ?? 0));

    final cheapest = variants.isNotEmpty ? variants.first : null;

    return {
      'id': row['id'],
      'name': row['name'],
      'unit': row['unit'],
      'category': row['category'],
      'brand': row['brand'],
      'image_url': row['image_url'],
      'master_product_id': row['master_product_id'],
      'price': (cheapest?['selling_price'] as num?) ?? 0,
      'variants': variants,
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

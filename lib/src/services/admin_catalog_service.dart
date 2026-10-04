import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_category.dart';
import '../models/master_product.dart';

/// Admin-only catalog management -- categories and the shared master
/// product catalog. Reads go straight to the tables (already readable by
/// any authenticated user); every write goes through a security-definer
/// RPC that re-checks the caller is an admin (see
/// supabase/add_admin_catalog_management.sql), since categories/
/// master_products intentionally have no regular-user write policy.
class AdminCatalogService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Every category (including inactive ones, unlike CategoryService's
  /// owner-facing fetchTopLevel) -- admin needs to see and reactivate a
  /// hidden category.
  static Future<List<CatalogCategory>> fetchAllCategories() async {
    final client = _clientOrNull;
    if (client == null) return const <CatalogCategory>[];

    final response = await client
        .from('categories')
        .select('id, name, parent_id, display_order, is_active')
        .order('display_order', ascending: true);

    return (response as List).map((row) => CatalogCategory.fromMap(row as Map<String, dynamic>)).toList();
  }

  static Future<void> upsertCategory({
    String? id,
    required String name,
    String? parentId,
    int displayOrder = 0,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.rpc('admin_category_upsert', params: {
      'p_id': id,
      'p_name': name.trim(),
      'p_parent_id': parentId,
      'p_display_order': displayOrder,
    });
  }

  static Future<void> setCategoryActive(String id, bool isActive) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.rpc('admin_category_set_active', params: {'p_id': id, 'p_is_active': isActive});
  }

  static Future<List<MasterProduct>> fetchMasterProducts({
    String? categoryName,
    String? query,
    bool includeInactive = true,
  }) async {
    final client = _clientOrNull;
    if (client == null) return const <MasterProduct>[];

    var builder = client.from('master_products').select();
    if (!includeInactive) builder = builder.eq('is_active', true);
    if (categoryName != null && categoryName.isNotEmpty && categoryName != 'All') {
      builder = builder.eq('category', categoryName);
    }
    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final safe = trimmed.replaceAll(RegExp(r'[,()%]'), '');
      builder = builder.or('product_name.ilike.%$safe%,brand.ilike.%$safe%,category.ilike.%$safe%');
    }

    final response = await builder.order('product_name', ascending: true);
    return (response as List).map((row) => MasterProduct.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// True if an active master catalog entry already matches this
  /// name+brand+category combination -- used both by the single-product
  /// form and the CSV import validator to flag duplicates before insert.
  static Future<bool> isDuplicateMasterProduct({
    required String productName,
    String? brand,
    String? category,
    String? excludeId,
  }) async {
    final client = _clientOrNull;
    if (client == null) return false;

    var builder = client
        .from('master_products')
        .select('id')
        .ilike('product_name', productName.trim())
        .eq('is_active', true);
    builder = (brand == null || brand.trim().isEmpty) ? builder.isFilter('brand', null) : builder.ilike('brand', brand.trim());
    if (category != null && category.trim().isNotEmpty) {
      builder = builder.eq('category', category.trim());
    }

    final rows = await builder.limit(2);
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (excludeId != null) {
      list.removeWhere((row) => row['id']?.toString() == excludeId);
    }
    return list.isNotEmpty;
  }

  static Future<void> upsertMasterProduct({
    String? id,
    required String productName,
    String? category,
    String? categoryId,
    String? subcategoryId,
    String? brand,
    String? imageUrl,
    String baseUnit = 'KG',
    Map<String, dynamic>? specifications,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.rpc('admin_master_product_upsert', params: {
      'p_id': id,
      'p_product_name': productName.trim(),
      'p_category': category,
      'p_category_id': categoryId,
      'p_subcategory_id': subcategoryId,
      'p_brand': brand,
      'p_image_url': imageUrl,
      'p_base_unit': baseUnit,
      'p_specifications': specifications,
    });
  }

  static Future<void> setMasterProductActive(String id, bool isActive) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.rpc('admin_master_product_set_active', params: {'p_id': id, 'p_is_active': isActive});
  }

  /// Inserts every row in one transaction (see the RPC) -- rows are plain
  /// maps shaped exactly like admin_master_product_bulk_import expects
  /// (product_name, category, category_id, subcategory_id, brand,
  /// image_url, base_unit, specifications). Returns how many were inserted.
  static Future<int> bulkImportMasterProducts(List<Map<String, dynamic>> rows) async {
    final client = _clientOrNull;
    if (client == null) return 0;
    final result = await client.rpc('admin_master_product_bulk_import', params: {'p_rows': rows});
    return (result as num?)?.toInt() ?? 0;
  }
}

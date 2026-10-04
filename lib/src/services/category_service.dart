import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_category.dart';

/// Reads the shared category/subcategory tree (`categories` table) -- the
/// backend-driven replacement for the old hardcoded kMasterProductCategories
/// list, so new business categories can be added later without an app
/// release.
class CategoryService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static List<CatalogCategory>? _topLevelCache;

  /// Top-level (parent_id is null) categories, in display order. Cached in
  /// memory for the session -- this list changes rarely but is read on
  /// every catalog/add-product screen open.
  static Future<List<CatalogCategory>> fetchTopLevel({bool forceRefresh = false}) async {
    if (!forceRefresh && _topLevelCache != null) return _topLevelCache!;
    final client = _clientOrNull;
    if (client == null) return const <CatalogCategory>[];

    final response = await client
        .from('categories')
        .select('id, name, parent_id, display_order')
        .filter('parent_id', 'is', null)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final categories = (response as List).map((row) => CatalogCategory.fromMap(row as Map<String, dynamic>)).toList();
    _topLevelCache = categories;
    return categories;
  }

  static Future<List<CatalogCategory>> fetchSubcategories(String parentId) async {
    final client = _clientOrNull;
    if (client == null) return const <CatalogCategory>[];

    final response = await client
        .from('categories')
        .select('id, name, parent_id, display_order')
        .eq('parent_id', parentId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List).map((row) => CatalogCategory.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// The top-level category ids this business has selected via "What does
  /// your business sell?" (business_categories). An empty result means the
  /// business hasn't chosen yet -- callers should fall back to showing
  /// every category rather than treating it as "sells nothing".
  static Future<Set<String>> fetchBusinessCategoryIds(String businessId) async {
    final client = _clientOrNull;
    if (client == null) return <String>{};

    final response = await client
        .from('business_categories')
        .select('category_id')
        .eq('business_id', businessId)
        .eq('is_active', true);

    return (response as List).map((row) => (row as Map<String, dynamic>)['category_id'].toString()).toSet();
  }

  /// Replaces this business's selected categories with [categoryIds] --
  /// newly checked ones are upserted active, previously-selected ones that
  /// got unchecked are soft-deactivated (never hard-deleted, consistent
  /// with how products/variants handle removal elsewhere in the app).
  static Future<void> saveBusinessCategories(String businessId, Set<String> categoryIds) async {
    final client = _clientOrNull;
    if (client == null) return;

    final existing = await fetchBusinessCategoryIds(businessId);
    final toAdd = categoryIds.difference(existing);
    final toRemove = existing.difference(categoryIds);

    if (toAdd.isNotEmpty) {
      await client.from('business_categories').upsert(
        toAdd
            .map((id) => {'business_id': businessId, 'category_id': id, 'is_active': true})
            .toList(),
        onConflict: 'business_id,category_id',
      );
    }

    if (toRemove.isNotEmpty) {
      await client
          .from('business_categories')
          .update({'is_active': false})
          .eq('business_id', businessId)
          .inFilter('category_id', toRemove.toList());
    }
  }
}

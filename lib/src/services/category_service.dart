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
}

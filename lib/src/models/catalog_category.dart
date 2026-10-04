/// A node in the shared category/subcategory tree (the `categories` table),
/// which replaced the old hardcoded grocery-only category list so new
/// business types can be added from the backend without an app release.
class CatalogCategory {
  final String id;
  final String name;
  final String? parentId;
  final int displayOrder;
  final bool isActive;

  const CatalogCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory CatalogCategory.fromMap(Map<String, dynamic> map) {
    return CatalogCategory(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      parentId: map['parent_id']?.toString(),
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

/// Maps a product to one of the bundled photos in
/// assets/images/products/ -- tries an exact product-name match first
/// (covers the seeded master catalog items that have dedicated photos),
/// then falls back to a category-level photo, then to the generic
/// placeholder. Always returns a usable asset path since
/// default_product.webp exists for every unmatched case.
String productImageAsset({required String productName, String? category}) {
  final normalizedName = productName.trim().toLowerCase();
  final exact = _productNameToAsset[normalizedName];
  if (exact != null) return _asset(exact);

  final categoryAsset = _categoryToAsset[category];
  if (categoryAsset != null) return _asset(categoryAsset);

  return _asset('default_product.webp');
}

String _asset(String fileName) => 'assets/images/products/$fileName';

const Map<String, String> _productNameToAsset = {
  'rice': 'rice.webp',
  'toor dal': 'toor_dal.webp',
  'moong dal': 'moong_dal.webp',
  'chana dal': 'chana_dal.webp',
  'atta': 'atta.webp',
  'sugar': 'sugar.webp',
  'mustard oil': 'mustard_oil.webp',
  'sunflower oil': 'sunflower_oil.webp',
  'onion': 'onion.webp',
  'potato': 'potato.webp',
};

const Map<String, String> _categoryToAsset = {
  'Spices': 'spices.webp',
  'Vegetables': 'vegetables.webp',
  'Packaged Food': 'packaged_food.webp',
};

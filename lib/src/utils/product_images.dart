/// Maps a product to one of the bundled photos in assets/images/products/
/// -- tries an exact product-name match first (covers every item that has
/// a dedicated photo, whether from the seeded master catalog or a custom
/// product an owner typed with a matching name), then falls back to a
/// category-level photo. Returns null when there's no match so callers can
/// show the icon-based placeholder instead of a real image.
String? productImageAsset({required String productName, String? category}) {
  final normalizedName = productName.trim().toLowerCase();
  final exact = _productNameToAsset[normalizedName];
  if (exact != null) return exact;

  return _categoryToAsset[category];
}

const String _p = 'assets/images/products';

const Map<String, String> _productNameToAsset = {
  // Rice & Grains
  'rice': '$_p/rice_grains/raw_rice.webp',
  'raw rice': '$_p/rice_grains/raw_rice.webp',
  'basmati rice': '$_p/rice_grains/basmati_rice.webp',
  'boiled rice': '$_p/rice_grains/boiled_rice.webp',
  'sona masoori rice': '$_p/rice_grains/sona_masoori_rice.webp',
  'oats': '$_p/rice_grains/oats.webp',
  'poha': '$_p/rice_grains/poha.webp',

  // Dal & Pulses
  'toor dal': '$_p/pulses_lentils/toor_dal.webp',
  'moong dal': '$_p/pulses_lentils/moong_dal.webp',
  'chana dal': '$_p/pulses_lentils/chana_dal.webp',
  'masoor dal': '$_p/pulses_lentils/masoor_dal.webp',
  'urad dal': '$_p/pulses_lentils/urad_dal.webp',
  'kabuli chana': '$_p/pulses_lentils/kabuli_chana.webp',
  'chickpeas': '$_p/pulses_lentils/kabuli_chana.webp',
  'mixed dal': '$_p/pulses_lentils/mixed_dal.webp',
  'rajma': '$_p/pulses_lentils/rajma.webp',
  'kidney beans': '$_p/pulses_lentils/rajma.webp',

  // Flour
  'atta': '$_p/flours_atta/wheat_atta.webp',
  'wheat atta': '$_p/flours_atta/wheat_atta.webp',
  'maida': '$_p/flours_atta/maida.webp',
  'suji': '$_p/flours_atta/suji.webp',
  'besan': '$_p/flours_atta/besan.webp',
  'jowar flour': '$_p/flours_atta/jowar_flour.webp',
  'ragi flour': '$_p/flours_atta/ragi_flour.webp',

  // Oil
  'mustard oil': '$_p/cooking_oils/mustard_oil.webp',
  'sunflower oil': '$_p/cooking_oils/sunflower_oil.webp',
  'groundnut oil': '$_p/cooking_oils/groundnut_oil.webp',
  'soyabean oil': '$_p/cooking_oils/soyabean_oil.webp',
  'soybean oil': '$_p/cooking_oils/soyabean_oil.webp',
  'coconut oil': '$_p/cooking_oils/coconut_oil.webp',

  // Spices
  'turmeric powder': '$_p/spices/turmeric_powder.webp',
  'red chilli powder': '$_p/spices/chilli_powder.webp',
  'chilli powder': '$_p/spices/chilli_powder.webp',
  'coriander powder': '$_p/spices/coriander_seeds.webp',
  'coriander seeds': '$_p/spices/coriander_seeds.webp',
  'cumin seeds': '$_p/spices/cumin_seeds.webp',
  'black pepper': '$_p/spices/black_pepper.webp',
  'cardamom': '$_p/spices/cardamom.webp',
  'cinnamon': '$_p/spices/cinnamon.webp',
  'garam masala': '$_p/spices/garam_masala.webp',

  // Vegetables
  'potato': '$_p/vegetables/potato.webp',
  'onion': '$_p/vegetables/onion.webp',
  'tomato': '$_p/vegetables/tomato.webp',
  'garlic': '$_p/vegetables/garlic.webp',
  'ginger': '$_p/vegetables/ginger.webp',
  'cabbage': '$_p/vegetables/cabbage.webp',
  'carrot': '$_p/vegetables/carrot.webp',
  'green chilli': '$_p/vegetables/green_chilli.webp',
  'green chili': '$_p/vegetables/green_chilli.webp',

  // Fruits
  'apple': '$_p/fruits/apple.webp',
  'banana': '$_p/fruits/banana.webp',
  'grapes': '$_p/fruits/grapes.webp',
  'mango': '$_p/fruits/mango.webp',
  'orange': '$_p/fruits/orange.webp',
  'pomegranate': '$_p/fruits/pomegranate.webp',

  // Dry fruits & nuts
  'almonds': '$_p/dry_fruits_nuts/almonds.webp',
  'cashews': '$_p/dry_fruits_nuts/cashews.webp',
  'pistachios': '$_p/dry_fruits_nuts/pistachios.webp',
  'raisins': '$_p/dry_fruits_nuts/raisins.webp',
  'walnuts': '$_p/dry_fruits_nuts/walnuts.webp',

  // Dairy & bakery
  'bread': '$_p/dairy_bakery/bread.webp',
  'butter': '$_p/dairy_bakery/butter.webp',
  'ghee': '$_p/dairy_bakery/ghee.webp',
  'milk': '$_p/dairy_bakery/milk_packet.webp',
  'milk packet': '$_p/dairy_bakery/milk_packet.webp',
  'paneer': '$_p/dairy_bakery/paneer.webp',

  // Sugar & salt
  'sugar': '$_p/sugar_salt/white_sugar.webp',
  'white sugar': '$_p/sugar_salt/white_sugar.webp',
  'brown sugar': '$_p/sugar_salt/brown_sugar.webp',
  'jaggery': '$_p/sugar_salt/jaggery.webp',
  'salt': '$_p/sugar_salt/salt.webp',

  // Beverages
  'tea leaves': '$_p/beverages/tea_leaves.webp',
  'tea': '$_p/beverages/tea_leaves.webp',
  'coffee powder': '$_p/beverages/coffee.webp',
  'coffee': '$_p/beverages/coffee.webp',
  'soft drink': '$_p/beverages/soft_drink.webp',
  'cold drink': '$_p/beverages/soft_drink.webp',
  'fruit juice': '$_p/beverages/fruit_juice.webp',
  'energy drink': '$_p/beverages/energy_drink.webp',

  // Packaged food
  'biscuits': '$_p/packaged_foods/biscuits.webp',
  'noodles': '$_p/packaged_foods/noodles.webp',

  // Snacks / namkeen
  'chips': '$_p/snacks_namkeen/chips.webp',
  'mixture': '$_p/snacks_namkeen/mixture.webp',
  'namkeen': '$_p/snacks_namkeen/namkeen.webp',
  'peanuts': '$_p/snacks_namkeen/peanuts.webp',

  // Miscellaneous
  'honey': '$_p/miscellaneous/honey.webp',
  'ketchup': '$_p/miscellaneous/ketchup.webp',
  'soya chunks': '$_p/miscellaneous/soya_chunks.webp',
  'vinegar': '$_p/miscellaneous/vinegar.webp',
};

const Map<String, String> _categoryToAsset = {
  'Spices': '$_p/spices.webp',
  'Vegetables': '$_p/vegetables.webp',
  'Packaged Food': '$_p/packaged_food.webp',
  'Oil': '$_p/cooking_oils/sunflower_oil.webp',
};

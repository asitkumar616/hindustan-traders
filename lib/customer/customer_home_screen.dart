import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/models/product_variant.dart';
import '../src/screens/login_screen.dart';
import '../src/services/auth_service.dart';
import '../src/services/cart_state.dart';
import '../src/services/customer_business_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/category_visuals.dart';
import '../src/utils/formatters.dart';
import '../src/utils/product_images.dart';
import '../src/widgets/app_card.dart';
import '../src/widgets/app_empty_state.dart';
import '../src/widgets/app_filter_chip.dart';
import '../src/widgets/app_loading_state.dart';
import '../src/widgets/app_quantity_stepper.dart';
import '../src/widgets/app_voice_bottom_nav.dart';
import '../src/widgets/draft_history_card.dart';
import '../src/widgets/notifications_card.dart';
import '../src/widgets/voice_order_card.dart';
import 'cart_screen.dart';
import 'customer_orders_screen.dart';
import 'customer_profile_screen.dart';
import 'product_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.businessId, required this.businessName});

  final String businessId;
  final String businessName;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late final CartState _cart;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _products = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _filteredProducts = const <Map<String, dynamic>>[];
  bool _isLoadingCatalog = true;
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _cart = CartState(businessId: widget.businessId, businessName: widget.businessName);
    _cart.addListener(_onCartChanged);
    _searchController.addListener(_applyFilter);
    refreshCatalog();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _cart.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> refreshCatalog() async {
    setState(() => _isLoadingCatalog = true);
    final products = await CustomerBusinessService.getProductsForBusiness(widget.businessId);
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoadingCatalog = false;
    });
    _applyFilter();
  }

  List<String> get _categories {
    final seen = <String>{};
    for (final product in _products) {
      final category = product['category']?.toString();
      if (category != null && category.isNotEmpty) seen.add(category);
    }
    return ['All', ...seen];
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final matchesQuery = query.isEmpty || (product['name']?.toString() ?? '').toLowerCase().contains(query);
        final matchesCategory = _category == 'All' || product['category']?.toString() == _category;
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<CartState>.value(value: _cart, child: const CartScreen()),
      ),
    );
  }

  void _openProductDetail(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<CartState>.value(
          value: _cart,
          child: ProductDetailScreen(product: product),
        ),
      ),
    );
  }

  void _openOrders() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()));
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerProfileScreen()));
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: NotificationsCard(businessId: widget.businessId)),
      ),
    );
  }

  void _showVoiceOrder() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VoiceOrderCard(businessId: widget.businessId),
                const SizedBox(height: AppSpacing.lg),
                const DraftHistoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.textPrimary,
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                widget.businessName,
                                style: AppTextStyles.heading,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showNotifications,
                        icon: const Icon(Icons.notifications_none_rounded),
                        color: AppColors.textPrimary,
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SearchField(controller: _searchController),
                ],
              ),
            ),
            if (_categories.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return AppFilterChip(
                      label: category,
                      selected: _category == category,
                      selectedColor: AppColors.navy,
                      onTap: () {
                        setState(() => _category = category);
                        _applyFilter();
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refreshCatalog,
                child: _isLoadingCatalog
                    ? const AppLoadingState()
                    : _filteredProducts.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            children: [
                              _products.isEmpty
                                  ? const AppEmptyState(
                                      icon: Icons.inventory_2_outlined,
                                      title: 'No Products Yet',
                                      message: 'This shop has not added any products yet.',
                                    )
                                  : const AppEmptyState(
                                      icon: Icons.search_off_rounded,
                                      title: 'No Matches',
                                      message: 'No products match your search.',
                                    ),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              0,
                              AppSpacing.xl,
                              _cart.isEmpty ? AppSpacing.xl : 96,
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: _ProductCard(
                                product: _filteredProducts[index],
                                cart: _cart,
                                onTap: () => _openProductDetail(_filteredProducts[index]),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _cart.isEmpty ? null : _CartSummaryBar(cart: _cart, onTap: _openCart),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.primary,
        accentLight: AppColors.primaryLight,
        leftItems: [
          AppNavItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.maybePop(context)),
          AppNavItem(icon: Icons.storefront_outlined, label: 'My Shops', onTap: () => Navigator.maybePop(context)),
        ],
        rightItems: [
          AppNavItem(icon: Icons.receipt_long_outlined, label: 'Orders', onTap: _openOrders),
          AppNavItem(icon: Icons.person_outline_rounded, label: 'Profile', onTap: _openProfile),
        ],
        onVoice: _showVoiceOrder,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Search products...',
          prefixIcon: Icon(Icons.search_rounded),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.cart, required this.onTap});

  final Map<String, dynamic> product;
  final CartState cart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = product['id']?.toString() ?? '';
    final name = product['name']?.toString() ?? 'Product';
    final brand = product['brand']?.toString();
    final variants = (product['variants'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ProductVariant.fromMap)
        .toList();
    final variantCount = variants.length;
    // Quick-add on the catalog card always targets the cheapest variant;
    // picking a different pack size means opening the product detail sheet.
    final defaultVariant = variants.isNotEmpty ? variants.first : null;
    final quantity = defaultVariant != null ? cart.quantityFor(defaultVariant.id) : 0.0;
    final category = product['category']?.toString();
    final visual = categoryVisual(category);
    final imageAsset = productImageAsset(productName: name, category: category);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.asset(
              imageAsset,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: visual.color.withValues(alpha: 0.1)),
                child: Icon(visual.icon, color: visual.color, size: 28),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.subheading),
                if (brand != null && brand.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(brand, style: AppTextStyles.caption),
                ],
                const SizedBox(height: 2),
                if (defaultVariant == null)
                  const Text('Not available', style: AppTextStyles.bodyMuted)
                else ...[
                  Text(
                    '₹${formatIndianAmount(defaultVariant.sellingPrice)} / ${defaultVariant.label}',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  if (variantCount > 1)
                    Text('$variantCount pack sizes available', style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          if (defaultVariant != null)
            quantity > 0
                ? AppQuantityStepper(
                    quantity: quantity,
                    unit: defaultVariant.packageType == 'LOOSE' ? defaultVariant.unit : defaultVariant.packageType,
                    onChanged: (next) => cart.setQuantity(
                      productId: id,
                      variantId: defaultVariant.id,
                      productName: name,
                      brand: brand,
                      variantQuantity: defaultVariant.quantity,
                      variantUnit: defaultVariant.unit,
                      packageType: defaultVariant.packageType,
                      price: defaultVariant.sellingPrice,
                      quantity: next,
                      minimumOrderQuantity: defaultVariant.minimumOrderQuantity,
                    ),
                  )
                : InkWell(
                    onTap: id.isEmpty
                        ? null
                        : () => cart.setQuantity(
                              productId: id,
                              variantId: defaultVariant.id,
                              productName: name,
                              brand: brand,
                              variantQuantity: defaultVariant.quantity,
                              variantUnit: defaultVariant.unit,
                              packageType: defaultVariant.packageType,
                              price: defaultVariant.sellingPrice,
                              quantity: defaultVariant.minimumOrderQuantity > 0 ? defaultVariant.minimumOrderQuantity : 1,
                              minimumOrderQuantity: defaultVariant.minimumOrderQuantity,
                            ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    ),
                  ),
        ],
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.cart, required this.onTap});

  final CartState cart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('${cart.itemCount} Items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: AppSpacing.sm),
                Text('₹${formatIndianAmount(cart.subtotal)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Spacer(),
                const Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

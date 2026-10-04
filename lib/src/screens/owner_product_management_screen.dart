import 'package:flutter/material.dart';
import '../models/product_variant.dart';
import '../models/voice_product_draft.dart';
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_secondary_button.dart';
import '../widgets/app_voice_bottom_nav.dart';
import '../widgets/ask_assistant_sheet.dart';
import '../widgets/catalog_product_image.dart';
import '../widgets/notification_bell.dart';
import '../widgets/notifications_card.dart';
import '../widgets/owner_nav_drawer.dart';
import '../widgets/voice_order_card.dart';
import 'login_screen.dart';
import 'owner_configure_variants_screen.dart';
import 'owner_custom_product_screen.dart';
import 'owner_customer_management_screen.dart';
import 'owner_master_catalog_screen.dart';
import 'owner_orders_screen.dart';

enum _SortOption { nameAsc, nameDesc, priceLowHigh, priceHighLow, recent }

extension on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.nameAsc:
        return 'Name (A-Z)';
      case _SortOption.nameDesc:
        return 'Name (Z-A)';
      case _SortOption.priceLowHigh:
        return 'Price: Low to High';
      case _SortOption.priceHighLow:
        return 'Price: High to Low';
      case _SortOption.recent:
        return 'Recently Added';
    }
  }
}

enum _StatusFilter { all, active, inactive }

extension on _StatusFilter {
  String get label {
    switch (this) {
      case _StatusFilter.all:
        return 'All Status';
      case _StatusFilter.active:
        return 'Active Only';
      case _StatusFilter.inactive:
        return 'Inactive Only';
    }
  }
}

class OwnerProductManagementScreen extends StatefulWidget {
  const OwnerProductManagementScreen({
    super.key,
    required this.businessId,
    this.autoOpenAdd = false,
    this.initialDraft,
  });

  final String businessId;
  final bool autoOpenAdd;

  /// Pre-fills the auto-opened Add Product flow -- used when the owner
  /// arrives here via the Ask Assistant ("Add Kohinoor rice 25 kg bag at 60
  /// rupees per kg") so they land on the manual form already filled in,
  /// still reviewing and confirming before it saves.
  final VoiceProductDraft? initialDraft;

  @override
  State<OwnerProductManagementScreen> createState() => _OwnerProductManagementScreenState();
}

class _OwnerProductManagementScreenState extends State<OwnerProductManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoadingProducts = true;
  String? _loadError;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  String _category = 'All';
  _StatusFilter _statusFilter = _StatusFilter.all;
  _SortOption _sortOption = _SortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadProducts();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAddManually(prefillDraft: widget.initialDraft);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final seen = <String>{};
    for (final product in _products) {
      final category = product['category']?.toString();
      if (category != null && category.isNotEmpty) seen.add(category);
    }
    return ['All', ...seen];
  }

  List<Map<String, dynamic>> _activeVariants(Map<String, dynamic> product) {
    return (product['variants'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where((variant) => variant['is_active'] != false)
        .toList();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    var results = _products.where((product) {
      final name = (product['name']?.toString() ?? '').toLowerCase();
      final brand = (product['brand']?.toString() ?? '').toLowerCase();
      final category = (product['category']?.toString() ?? '').toLowerCase();
      final matchesQuery = query.isEmpty || name.contains(query) || brand.contains(query) || category.contains(query);
      final matchesCategory = _category == 'All' || product['category']?.toString() == _category;
      final isActive = product['is_active'] != false;
      final matchesStatus = switch (_statusFilter) {
        _StatusFilter.all => true,
        _StatusFilter.active => isActive,
        _StatusFilter.inactive => !isActive,
      };
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();

    results.sort((a, b) {
      switch (_sortOption) {
        case _SortOption.nameAsc:
          return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
        case _SortOption.nameDesc:
          return (b['name']?.toString() ?? '').compareTo(a['name']?.toString() ?? '');
        case _SortOption.priceLowHigh:
          return ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0);
        case _SortOption.priceHighLow:
          return ((b['price'] as num?) ?? 0).compareTo((a['price'] as num?) ?? 0);
        case _SortOption.recent:
          return (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? '');
      }
    });

    setState(() => _filteredProducts = results);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _loadError = null;
    });
    try {
      final products = await CustomerBusinessService.getProductsForBusiness(widget.businessId, includeInactive: true);
      if (!mounted) return;
      setState(() => _products = products);
      _applyFilter();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  void _showAddProductSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Products', style: AppTextStyles.heading),
              const SizedBox(height: 2),
              const Text('Choose how you want to add products.', style: AppTextStyles.bodyMuted),
              const SizedBox(height: AppSpacing.lg),
              _AddOptionTile(
                icon: Icons.storefront_rounded,
                iconBg: AppColors.categoryDal,
                title: 'Add from Catalog',
                subtitle: 'Choose ready-made grocery products and set your own price and stock.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAddFromCatalog();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _AddOptionTile(
                icon: Icons.add_box_rounded,
                iconBg: AppColors.ownerPrimary,
                title: 'Add Manually',
                subtitle: 'Create a product that is not available in the catalog.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAddManually();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddFromCatalog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OwnerMasterCatalogScreen(businessId: widget.businessId)),
    ).then((_) => _loadProducts());
  }

  void _openAddManually({VoiceProductDraft? prefillDraft}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OwnerCustomProductScreen(businessId: widget.businessId, initialDraft: prefillDraft)),
    ).then((_) => _loadProducts());
  }

  void _editVariants(Map<String, dynamic> product) {
    final variants = (product['variants'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ProductVariant.fromMap)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerConfigureVariantsScreen(
          productId: product['id']?.toString() ?? '',
          productName: product['name']?.toString() ?? 'Product',
          businessId: widget.businessId,
          baseUnit: product['unit']?.toString() ?? 'KG',
          existingVariants: variants,
          category: product['category']?.toString(),
          brand: product['brand']?.toString(),
          isProductActive: product['is_active'] != false,
        ),
      ),
    ).then((_) => _loadProducts());
  }

  Future<void> _quickUpdatePrice(Map<String, dynamic> product) async {
    final variants = _activeVariants(product);
    if (variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No selling options configured yet. Use Edit to add one first.')),
      );
      return;
    }

    final controllers = {
      for (final variant in variants) variant['id'].toString(): TextEditingController(text: (variant['selling_price'] as num? ?? 0).toStringAsFixed(0)),
    };
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Update Price', style: AppTextStyles.heading),
                Text(product['name']?.toString() ?? 'Product', style: AppTextStyles.bodyMuted),
                const SizedBox(height: AppSpacing.lg),
                ...variants.map((variant) {
                  final label = ProductVariant.fromMap(variant).label;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: TextField(
                      controller: controllers[variant['id'].toString()],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Price / $label (₹)'),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(sheetContext)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Update Price',
                        loading: saving,
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() => saving = true);
                                try {
                                  for (final variant in variants) {
                                    final id = variant['id'].toString();
                                    final price = double.tryParse(controllers[id]!.text.trim());
                                    if (price == null || price <= 0) continue;
                                    await CustomerBusinessService.updateVariant(
                                      variantId: id,
                                      sellingPrice: price,
                                      notifyBusinessId: widget.businessId,
                                      notifyProductName: product['name']?.toString(),
                                    );
                                  }
                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                } catch (error) {
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(content: Text('Unable to update price: $error')),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (mounted) _loadProducts();
  }

  Future<void> _quickUpdateStock(Map<String, dynamic> product) async {
    final variants = _activeVariants(product);
    if (variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No selling options configured yet. Use Edit to add one first.')),
      );
      return;
    }

    final controllers = {
      for (final variant in variants) variant['id'].toString(): TextEditingController(text: (variant['stock_quantity'] as num?)?.toStringAsFixed(0) ?? ''),
    };
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Update Stock', style: AppTextStyles.heading),
                Text(product['name']?.toString() ?? 'Product', style: AppTextStyles.bodyMuted),
                const SizedBox(height: AppSpacing.lg),
                ...variants.map((variant) {
                  final v = ProductVariant.fromMap(variant);
                  final current = v.stockQuantity;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current == null ? '${v.label} · stock not tracked' : '${v.label} · current: ${formatIndianAmount(current)}',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: controllers[variant['id'].toString()],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'New Stock', isDense: true),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(sheetContext)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Update Stock',
                        loading: saving,
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() => saving = true);
                                try {
                                  for (final variant in variants) {
                                    final id = variant['id'].toString();
                                    final text = controllers[id]!.text.trim();
                                    if (text.isEmpty) continue;
                                    final stock = double.tryParse(text);
                                    if (stock == null || stock < 0) continue;
                                    await CustomerBusinessService.updateVariant(variantId: id, stockQuantity: stock);
                                  }
                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                } catch (error) {
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(content: Text('Unable to update stock: $error')),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (mounted) _loadProducts();
  }

  Future<void> _toggleActive(Map<String, dynamic> product) async {
    final isActive = product['is_active'] != false;
    try {
      await CustomerBusinessService.setProductActive(product['id']?.toString() ?? '', !isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isActive ? 'Product deactivated.' : 'Product activated.')),
      );
      await _loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update status: $error')));
    }
  }

  Future<void> _duplicate(Map<String, dynamic> product) async {
    try {
      await CustomerBusinessService.duplicateProduct(productId: product['id']?.toString() ?? '', businessId: widget.businessId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product duplicated.')));
      await _loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to duplicate product: $error')));
    }
  }

  void _showProductMenu(Map<String, dynamic> product) {
    final isActive = product['is_active'] != false;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Product'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editVariants(product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: const Text('Update Price'),
              onTap: () {
                Navigator.pop(sheetContext);
                _quickUpdatePrice(product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_outlined),
              title: const Text('Update Stock'),
              onTap: () {
                Navigator.pop(sheetContext);
                _quickUpdateStock(product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(sheetContext);
                _duplicate(product);
              },
            ),
            ListTile(
              leading: Icon(isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: isActive ? AppColors.danger : AppColors.success),
              title: Text(
                isActive ? 'Deactivate' : 'Activate',
                style: TextStyle(color: isActive ? AppColors.danger : AppColors.success),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _toggleActive(product);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotifications() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: NotificationsCard(businessId: widget.businessId)),
      ),
    );
  }

  void _showVoiceOrderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: VoiceOrderCard(businessId: widget.businessId)),
      ),
    );
  }

  void _showSortMenu() async {
    final selected = await showModalBottomSheet<_SortOption>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _SortOption.values
              .map((option) => RadioListTile<_SortOption>(
                    value: option,
                    groupValue: _sortOption,
                    title: Text(option.label),
                    activeColor: AppColors.ownerPrimary,
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _sortOption = selected);
      _applyFilter();
    }
  }

  void _showStatusFilterMenu() async {
    final selected = await showModalBottomSheet<_StatusFilter>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _StatusFilter.values
              .map((option) => RadioListTile<_StatusFilter>(
                    value: option,
                    groupValue: _statusFilter,
                    title: Text(option.label),
                    activeColor: AppColors.ownerPrimary,
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _statusFilter = selected);
      _applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surfaceMuted,
      drawer: OwnerNavDrawer(
        businessId: widget.businessId,
        onDashboard: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onNavigate: (screen) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
        onAskAssistant: () {
          Navigator.pop(context);
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
            builder: (_) => AskAssistantSheet(businessId: widget.businessId),
          );
        },
        onLogout: () async {
          Navigator.pop(context);
          await AuthService.signOut();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      ),
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
                      const Spacer(),
                      NotificationBell(businessIds: [widget.businessId], onTap: _showNotifications),
                    ],
                  ),
                  const Text('Products', style: AppTextStyles.heading),
                  const SizedBox(height: 2),
                  const Text('Manage your product catalogue, prices and stock.', style: AppTextStyles.bodyMuted),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: _SearchField(controller: _searchController)),
                      const SizedBox(width: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _showAddProductSheet,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return AppFilterChip(
                          label: category,
                          selected: _category == category,
                          selectedColor: AppColors.ownerPrimary,
                          onTap: () {
                            setState(() => _category = category);
                            _applyFilter();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_filteredProducts.length} Products', style: AppTextStyles.bodyMuted),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _showStatusFilterMenu,
                            icon: const Icon(Icons.filter_list_rounded, size: 18),
                            label: const Text('Filter'),
                          ),
                          TextButton.icon(
                            onPressed: _showSortMenu,
                            icon: const Icon(Icons.swap_vert_rounded, size: 18),
                            label: const Text('Sort'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                child: _isLoadingProducts
                    ? const AppLoadingState()
                    : _loadError != null
                        ? ListView(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            children: [
                              const SizedBox(height: AppSpacing.xl),
                              const Text('Something went wrong. Unable to load your products.', style: AppTextStyles.bodyMuted),
                              const SizedBox(height: AppSpacing.md),
                              AppSecondaryButton(label: 'Retry', onPressed: _loadProducts),
                            ],
                          )
                        : _products.isEmpty
                            ? ListView(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                                children: [
                                  const SizedBox(height: AppSpacing.xl),
                                  const AppEmptyState(
                                    icon: Icons.inventory_2_outlined,
                                    title: 'No Products Yet',
                                    message: 'Start by adding products from our catalog or create your own product.',
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  AppPrimaryButton(label: 'Add from Catalog', icon: Icons.storefront_rounded, onPressed: _openAddFromCatalog),
                                  const SizedBox(height: AppSpacing.md),
                                  AppSecondaryButton(label: 'Add Manually', icon: Icons.add_box_rounded, onPressed: () => _openAddManually()),
                                ],
                              )
                            : _filteredProducts.isEmpty
                                ? ListView(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                                    children: const [
                                      SizedBox(height: AppSpacing.xl),
                                      AppEmptyState(
                                        icon: Icons.search_off_rounded,
                                        title: 'No Matches',
                                        message: 'No products match your search or filters.',
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                                    itemCount: _filteredProducts.length,
                                    itemBuilder: (_, index) {
                                      final product = _filteredProducts[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                        child: _OwnerProductCard(
                                          product: product,
                                          onEdit: () => _editVariants(product),
                                          onUpdateStock: () => _quickUpdateStock(product),
                                          onUpdatePrice: () => _quickUpdatePrice(product),
                                          onMenu: () => _showProductMenu(product),
                                        ),
                                      );
                                    },
                                  ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.primaryDark,
        accentLight: AppColors.primaryLight,
        leftItems: [
          AppNavItem(icon: Icons.home_rounded, label: 'Dashboard', onTap: () => Navigator.maybePop(context)),
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerOrdersScreen(businessId: widget.businessId))),
          ),
        ],
        rightItems: [
          const AppNavItem(icon: Icons.inventory_2_rounded, label: 'Products', active: true),
          AppNavItem(
            icon: Icons.groups_2_outlined,
            label: 'Customers',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerCustomerManagementScreen(businessId: widget.businessId))),
          ),
        ],
        onVoice: _showVoiceOrderSheet,
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  const _AddOptionTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconBg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.subheading),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
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
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Search products, brand or category...',
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

class _OwnerProductCard extends StatelessWidget {
  const _OwnerProductCard({
    required this.product,
    required this.onEdit,
    required this.onUpdateStock,
    required this.onUpdatePrice,
    required this.onMenu,
  });

  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onUpdateStock;
  final VoidCallback onUpdatePrice;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Product';
    final brand = product['brand']?.toString();
    final category = product['category']?.toString();
    final isActive = product['is_active'] != false;
    final variants = (product['variants'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where((variant) => variant['is_active'] != false)
        .map(ProductVariant.fromMap)
        .toList();
    final subtitle = [category, brand].where((value) => value != null && value.isNotEmpty).join(' • ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CatalogProductImage(
                productName: name,
                category: category,
                imageUrl: product['image_url']?.toString(),
                size: 72,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name, style: AppTextStyles.subheading, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFE1F7E8) : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: isActive ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) Text(subtitle, style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.xs),
                    if (variants.isEmpty)
                      const Text('No selling options configured yet', style: AppTextStyles.bodyMuted)
                    else
                      ...variants.map((variant) {
                        final stock = variant.stockQuantity;
                        final totalInBase = variant.quantity != 1 && stock != null ? stock * variant.quantity : null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('₹${formatIndianAmount(variant.sellingPrice)} / ${variant.label}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                              ),
                              if (stock != null)
                                Text(
                                  totalInBase != null
                                      ? '${formatIndianAmount(stock)} in stock (${formatIndianAmount(totalInBase)} ${variant.unit})'
                                      : '${formatIndianAmount(stock)} in stock',
                                  style: TextStyle(fontSize: 11, color: stock <= 0 ? AppColors.danger : AppColors.success, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              IconButton(onPressed: onMenu, icon: const Icon(Icons.more_vert_rounded), color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _CardActionButton(icon: Icons.edit_outlined, label: 'Edit', color: AppColors.info, onTap: onEdit)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _CardActionButton(icon: Icons.inventory_outlined, label: 'Stock', color: AppColors.warning, onTap: onUpdateStock)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _CardActionButton(icon: Icons.sell_outlined, label: 'Price', color: AppColors.success, onTap: onUpdatePrice)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

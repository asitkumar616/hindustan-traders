import 'package:flutter/material.dart';
import '../models/catalog_category.dart';
import '../models/master_product.dart';
import '../services/category_service.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/catalog_product_image.dart';
import 'owner_business_categories_screen.dart';
import 'owner_bulk_configure_products_screen.dart';
import 'owner_configure_variants_screen.dart';
import 'owner_custom_product_screen.dart';

/// "Add from Catalog" -- browse the shared master grocery catalog and link a
/// product into this owner's shop, then immediately configure its selling
/// variants. Never creates a duplicate master_products row per owner: this
/// always creates just the owner's own `products` row, linked via
/// master_product_id.
class OwnerMasterCatalogScreen extends StatefulWidget {
  const OwnerMasterCatalogScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerMasterCatalogScreen> createState() => _OwnerMasterCatalogScreenState();
}

class _OwnerMasterCatalogScreenState extends State<OwnerMasterCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _category = 'All';
  bool _loading = true;
  List<MasterProduct> _products = const <MasterProduct>[];
  List<CatalogCategory> _allCategories = const <CatalogCategory>[];
  Set<String> _businessCategoryIds = <String>{};
  bool _adding = false;
  bool _bulkAdding = false;
  final Set<String> _selectedIds = <String>{};

  /// The categories shown as chips: this business's own selection ("What
  /// does your business sell?"), or every category when it hasn't chosen
  /// yet -- so an owner who never visited that screen sees the same full
  /// list as before this feature existed.
  List<CatalogCategory> get _visibleCategories => _businessCategoryIds.isEmpty
      ? _allCategories
      : _allCategories.where((c) => _businessCategoryIds.contains(c.id)).toList();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadCategories() async {
    final categories = await CategoryService.fetchTopLevel();
    final selected = await CategoryService.fetchBusinessCategoryIds(widget.businessId);
    if (!mounted) return;
    setState(() {
      _allCategories = categories;
      _businessCategoryIds = selected;
    });
  }

  Future<void> _openCategoryPicker() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerBusinessCategoriesScreen(businessId: widget.businessId)),
    );
    if (saved == true) {
      await _loadCategories();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selectedIds.clear();
    });
    try {
      final products = await CustomerBusinessService.getMasterProducts(
        category: _category == 'All' ? null : _category,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _products = products);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load catalog: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Asks which brand this is before creating the product -- lets the same
  /// catalog entry (e.g. "Rice") be added more than once under different
  /// brands ("Kohinoor Rice", "India Gate Rice"), each becoming its own
  /// card in the shop.
  Future<({String brand, String displayName})?> _promptBrand(MasterProduct product) async {
    final brandController = TextEditingController();
    final nameController = TextEditingController(text: product.productName);
    var nameEdited = false;

    return showModalBottomSheet<({String brand, String displayName})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add ${product.productName} to My Shop', style: AppTextStyles.heading),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'If you stock more than one brand, add each one separately -- they\'ll show as separate cards.',
                      style: AppTextStyles.bodyMuted,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: brandController,
                      decoration: const InputDecoration(labelText: 'Brand (e.g. Kohinoor)'),
                      onChanged: (value) {
                        if (nameEdited) return;
                        setSheetState(() {
                          nameController.text = value.trim().isEmpty ? product.productName : '${value.trim()} ${product.productName}';
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Display Name'),
                      onChanged: (_) => nameEdited = true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(
                      label: 'Continue to Selling Options',
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        (brand: brandController.text.trim(), displayName: nameController.text.trim()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addToShop(MasterProduct product) async {
    final choice = await _promptBrand(product);
    if (choice == null) return;

    setState(() => _adding = true);
    try {
      final existing = await CustomerBusinessService.findExistingCatalogProduct(
        businessId: widget.businessId,
        masterProductId: product.id,
        brand: choice.brand,
      );
      if (existing != null) {
        if (!mounted) return;
        setState(() => _adding = false);
        await _showAlreadyInShopDialog(existing);
        return;
      }

      final created = await CustomerBusinessService.createProductFromMasterProduct(
        businessId: widget.businessId,
        masterProduct: product,
        customName: choice.displayName,
        brandOverride: choice.brand,
      );
      if (!mounted || created == null) return;

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerConfigureVariantsScreen(
            productId: created['id']?.toString() ?? '',
            productName: created['name']?.toString() ?? product.productName,
            businessId: widget.businessId,
            baseUnit: product.baseUnit,
          ),
        ),
      );

      if (!mounted) return;
      if (saved == true) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add product: $error')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// Links every checked catalog product into the shop in one pass -- no
  /// per-item brand prompt (the bulk path always uses the catalog entry's
  /// own brand, matching the spec's "configure everything at once" UX),
  /// then opens one shared screen to set each one's price/stock.
  Future<void> _addSelectedToShop() async {
    final selectedProducts = _products.where((p) => _selectedIds.contains(p.id)).toList();
    if (selectedProducts.isEmpty) return;

    setState(() => _bulkAdding = true);
    final created = <BulkCatalogProduct>[];
    final skipped = <String>[];
    try {
      for (final product in selectedProducts) {
        final existing = await CustomerBusinessService.findExistingCatalogProduct(
          businessId: widget.businessId,
          masterProductId: product.id,
          brand: product.brand ?? '',
        );
        if (existing != null) {
          skipped.add(product.productName);
          continue;
        }

        final row = await CustomerBusinessService.createProductFromMasterProduct(
          businessId: widget.businessId,
          masterProduct: product,
        );
        if (row == null) continue;
        created.add(BulkCatalogProduct(
          id: row['id']?.toString() ?? '',
          name: row['name']?.toString() ?? product.productName,
          unit: product.baseUnit,
          category: product.category,
          brand: row['brand']?.toString(),
          imageUrl: row['image_url']?.toString(),
        ));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _bulkAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add products: $error')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _bulkAdding = false;
      _selectedIds.clear();
    });

    if (skipped.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Already in your shop, skipped: ${skipped.join(', ')}')),
      );
    }
    if (created.isEmpty) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerBulkConfigureProductsScreen(businessId: widget.businessId, products: created),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      Navigator.pop(context, true);
    }
  }

  /// Prevents a silent duplicate when this owner already added this catalog
  /// entry under the same brand. An active match just gets acknowledged; an
  /// inactive one (previously deactivated) offers to bring it back instead
  /// of creating a second row for the same product.
  Future<void> _showAlreadyInShopDialog(Map<String, dynamic> existing) async {
    final isActive = existing['is_active'] != false;
    final name = existing['name']?.toString() ?? 'This product';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Already in your shop'),
        content: Text(
          isActive
              ? '$name is already in your shop.'
              : '$name was previously removed from your shop.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          if (isActive)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context, true);
              },
              child: const Text('View Product'),
            )
          else
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await CustomerBusinessService.setProductActive(existing['id']?.toString() ?? '', true);
                  if (!mounted) return;
                  Navigator.pop(context, true);
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to reactivate: $error')));
                }
              },
              child: const Text('Reactivate Product'),
            ),
        ],
      ),
    );
  }

  Future<void> _openCustomProduct() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerCustomProductScreen(businessId: widget.businessId)),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ..._visibleCategories.map((c) => c.name)];
    final hasSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Product Catalog'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Text('Choose products to add to your shop.', style: AppTextStyles.bodyMuted),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search rice, dal, oil, atta...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _load),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == categories.length) {
                    return InkWell(
                      onTap: _openCategoryPicker,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.ownerPrimary),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: AppColors.ownerPrimary),
                            SizedBox(width: 2),
                            Text('Category', style: TextStyle(color: AppColors.ownerPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  }
                  final category = categories[index];
                  return AppFilterChip(
                    label: category,
                    selected: _category == category,
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () {
                      setState(() => _category = category);
                      _load();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _loading
                  ? const AppLoadingState()
                  : _products.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                          children: const [
                            AppEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No Matches',
                              message: 'Try a different search or create a custom product below.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final selected = _selectedIds.contains(product.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      activeColor: AppColors.ownerPrimary,
                                      onChanged: (_) => setState(() {
                                        if (selected) {
                                          _selectedIds.remove(product.id);
                                        } else {
                                          _selectedIds.add(product.id);
                                        }
                                      }),
                                    ),
                                    CatalogProductImage(
                                      productName: product.productName,
                                      category: product.category,
                                      imageUrl: product.imageUrl,
                                      size: 72,
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.productName, style: AppTextStyles.subheading),
                                          if (product.brand != null && product.brand!.isNotEmpty)
                                            Text(product.brand!, style: AppTextStyles.bodyMuted),
                                        ],
                                      ),
                                    ),
                                    if (!hasSelection)
                                      FilledButton(
                                        onPressed: _adding ? null : () => _addToShop(product),
                                        child: const Text('Add'),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (hasSelection)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
                child: AppPrimaryButton(
                  label: 'Add ${_selectedIds.length} Product${_selectedIds.length == 1 ? '' : 's'}',
                  onPressed: _bulkAdding ? null : _addSelectedToShop,
                  loading: _bulkAdding,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
                child: OutlinedButton.icon(
                  onPressed: _openCustomProduct,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Custom Product'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/master_product.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_loading_state.dart';
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
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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

  Future<void> _addToShop(MasterProduct product) async {
    setState(() => _adding = true);
    try {
      final created = await CustomerBusinessService.createProductFromMasterProduct(
        businessId: widget.businessId,
        masterProduct: product,
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
    final categories = ['All', ...kMasterProductCategories];

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Add Products to My Shop'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search grocery products...',
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
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
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
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.ownerPrimary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.ownerPrimary),
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
                                    FilledButton(
                                      onPressed: _adding ? null : () => _addToShop(product),
                                      child: const Text('Add to My Shop'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
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

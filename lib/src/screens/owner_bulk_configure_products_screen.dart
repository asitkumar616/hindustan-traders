import 'package:flutter/material.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/catalog_product_image.dart';
import 'owner_configure_variants_screen.dart';

/// One product just linked into the shop from the catalog, waiting for a
/// price/stock here (or a full "More Settings" pass).
class BulkCatalogProduct {
  const BulkCatalogProduct({
    required this.id,
    required this.name,
    required this.unit,
    this.category,
    this.brand,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String unit;
  final String? category;
  final String? brand;
  final String? imageUrl;
}

class _Row {
  _Row(this.product)
      : priceController = TextEditingController(),
        stockController = TextEditingController();

  final BulkCatalogProduct product;
  final TextEditingController priceController;
  final TextEditingController stockController;

  /// True once "More Settings" has saved selling options for this product
  /// directly -- its price/stock fields here are then skipped on Save, since
  /// OwnerConfigureVariantsScreen already created the variant itself.
  bool configuredSeparately = false;

  void dispose() {
    priceController.dispose();
    stockController.dispose();
  }
}

/// Shown right after the owner bulk-selects products in Add-from-Catalog --
/// one quick price/stock per product instead of forcing N separate "Add
/// Product" screens. "More Settings" on any row still opens the full
/// OwnerConfigureVariantsScreen for that one product (multiple pack sizes,
/// minimum order quantity, etc.) when the quick price/stock isn't enough.
class OwnerBulkConfigureProductsScreen extends StatefulWidget {
  const OwnerBulkConfigureProductsScreen({
    super.key,
    required this.businessId,
    required this.products,
  });

  final String businessId;
  final List<BulkCatalogProduct> products;

  @override
  State<OwnerBulkConfigureProductsScreen> createState() => _OwnerBulkConfigureProductsScreenState();
}

class _OwnerBulkConfigureProductsScreenState extends State<OwnerBulkConfigureProductsScreen> {
  late final List<_Row> _rows = widget.products.map((p) => _Row(p)).toList();
  bool _saving = false;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _openMoreSettings(_Row row) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerConfigureVariantsScreen(
          productId: row.product.id,
          productName: row.product.name,
          businessId: widget.businessId,
          baseUnit: row.product.unit,
          category: row.product.category,
          brand: row.product.brand,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() => row.configuredSeparately = true);
    }
  }

  Future<void> _save() async {
    final pending = _rows.where((r) => !r.configuredSeparately).toList();

    for (final row in pending) {
      final priceText = row.priceController.text.trim();
      if (priceText.isEmpty) continue;
      final price = double.tryParse(priceText);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid price for ${row.product.name}.')),
        );
        return;
      }
    }

    final toSave = pending.where((r) => r.priceController.text.trim().isNotEmpty).toList();
    final allDone = pending.isEmpty && _rows.every((r) => r.configuredSeparately);
    if (toSave.isEmpty && !allDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a price for at least one product, or use More Settings.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      for (final row in toSave) {
        final price = double.parse(row.priceController.text.trim());
        final stock = double.tryParse(row.stockController.text.trim());
        await CustomerBusinessService.addVariant(
          productId: row.product.id,
          quantity: 1,
          unit: row.product.unit,
          packageType: 'LOOSE',
          sellingPrice: price,
          minimumOrderQuantity: 1,
          stockQuantity: stock,
        );
        await CustomerBusinessService.notifyCustomersOfNewProduct(
          businessId: widget.businessId,
          productName: row.product.name,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save products: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _rows.length;
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text('Configure $count Product${count == 1 ? '' : 's'}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CatalogProductImage(
                                productName: row.product.name,
                                category: row.product.category ?? '',
                                imageUrl: row.product.imageUrl,
                                size: 48,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(row.product.name, style: AppTextStyles.subheading, overflow: TextOverflow.ellipsis),
                              ),
                              TextButton(
                                onPressed: () => _openMoreSettings(row),
                                child: const Text('More Settings'),
                              ),
                            ],
                          ),
                          if (row.configuredSeparately)
                            const Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                'Configured ✓',
                                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            )
                          else ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: row.priceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: 'Price per ${row.product.unit} (₹)', isDense: true),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextField(
                                    controller: row.stockController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Stock (optional)', isDense: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: AppPrimaryButton(
                label: 'Save $count Product${count == 1 ? '' : 's'}',
                onPressed: _saving ? null : _save,
                loading: _saving,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

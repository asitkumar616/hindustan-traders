import 'package:flutter/material.dart';
import '../models/master_product.dart';
import '../models/product_variant.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_secondary_button.dart';

class _SuggestedSize {
  const _SuggestedSize(this.quantity, this.unit, this.packageType);
  final double quantity;
  final String unit;
  final String packageType;

  String get label {
    final qty = quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();
    final base = '$qty $unit';
    return packageType == 'LOOSE' ? base : '$base $packageType';
  }
}

/// The two suggestions that cover the common case (sell loose by the base
/// unit, and sell in one bulk pack size) -- matches the redesigned "Sell by
/// KG / Sell by Bag" checkboxes. Anything beyond this (a 5 KG pack, a second
/// bag size, a carton of pieces...) is still fully supported via "Add
/// Custom Size", which was never limited to these two.
List<_SuggestedSize> _suggestedSizesFor(String baseUnit) {
  switch (baseUnit) {
    case 'LTR':
    case 'ML':
      return const [
        _SuggestedSize(1, 'LTR', 'LOOSE'),
        _SuggestedSize(15, 'LTR', 'BOX'),
      ];
    case 'PCS':
      return const [
        _SuggestedSize(1, 'PCS', 'LOOSE'),
        _SuggestedSize(12, 'PCS', 'BOX'),
      ];
    default:
      return const [
        _SuggestedSize(1, 'KG', 'LOOSE'),
        _SuggestedSize(25, 'KG', 'BAG'),
      ];
  }
}

/// One row's editable state -- either a suggested size the owner has ticked
/// on, or a custom size they added. sellingPrice/moq/stock are left as text
/// so partially-typed values don't get clobbered by parsing on every
/// keystroke; parsed only on Save.
class _VariantRow {
  _VariantRow({
    this.existingVariantId,
    required double quantity,
    required this.unit,
    required this.packageType,
    String? price,
    String? moq,
    String? stock,
    String? mrp,
    String? taxRate,
    String? sku,
    this.enabled = true,
  })  : quantityController = TextEditingController(
          text: quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString(),
        ),
        priceController = TextEditingController(text: price ?? ''),
        moqController = TextEditingController(text: moq ?? '1'),
        stockController = TextEditingController(text: stock ?? ''),
        mrpController = TextEditingController(text: mrp ?? ''),
        taxRateController = TextEditingController(text: taxRate ?? ''),
        skuController = TextEditingController(text: sku ?? '');

  final String? existingVariantId;
  final String unit;
  final String packageType;
  bool enabled;
  bool showAdvanced = false;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final TextEditingController moqController;
  final TextEditingController stockController;
  final TextEditingController mrpController;
  final TextEditingController taxRateController;
  final TextEditingController skuController;

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 1;

  /// LOOSE rows read as "Sell by KG (Small quantity)"; bulk-pack rows read
  /// as "Sell by Bag (Bulk quantity)" -- falls back to the plain size label
  /// for anything a custom size adds beyond these two common shapes.
  bool get _isCommonLoose => packageType == 'LOOSE';
  String get title => _isCommonLoose ? 'Sell by $unit' : 'Sell by $packageType';
  String get subtitle => _isCommonLoose ? 'Small quantity' : 'Bulk quantity';

  String get label {
    final qty = quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();
    final base = '$qty $unit';
    return packageType == 'LOOSE' ? base : '$base $packageType';
  }

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    moqController.dispose();
    stockController.dispose();
    mrpController.dispose();
    taxRateController.dispose();
    skuController.dispose();
  }
}

/// Lets an owner pick which pack sizes they sell a product in and set each
/// one's own price -- deliberately never derives one price from another
/// (e.g. bag price is NOT quantity x loose price), since a wholesaler may
/// intentionally price a full bag below the per-kg rate. Also doubles as
/// the "Edit Product" screen when [existingVariants] is non-empty.
class OwnerConfigureVariantsScreen extends StatefulWidget {
  const OwnerConfigureVariantsScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.businessId,
    this.baseUnit = 'KG',
    this.existingVariants = const <ProductVariant>[],
    this.category,
    this.brand,
    this.isProductActive = true,
  });

  final String productId;
  final String productName;
  final String businessId;
  final String baseUnit;
  final List<ProductVariant> existingVariants;
  final String? category;
  final String? brand;
  final bool isProductActive;

  @override
  State<OwnerConfigureVariantsScreen> createState() => _OwnerConfigureVariantsScreenState();
}

class _OwnerConfigureVariantsScreenState extends State<OwnerConfigureVariantsScreen> {
  late List<_VariantRow> _rows;
  late bool _isProductActive = widget.isProductActive;
  bool _saving = false;

  bool get _isEditing => widget.existingVariants.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final suggestions = _suggestedSizesFor(widget.baseUnit);

    // Start from existing variants (edit mode) -- always shown regardless of
    // whether they match a suggested size, so a previously-added custom size
    // is never silently dropped from the form.
    _rows = widget.existingVariants
        .map((v) => _VariantRow(
              existingVariantId: v.id,
              quantity: v.quantity,
              unit: v.unit,
              packageType: v.packageType,
              price: v.sellingPrice.toStringAsFixed(0),
              moq: v.minimumOrderQuantity.toStringAsFixed(0),
              stock: v.stockQuantity?.toStringAsFixed(0),
              mrp: v.mrp?.toStringAsFixed(0),
              taxRate: v.taxRate?.toStringAsFixed(1),
              sku: v.sku,
              enabled: v.isActive,
            ))
        .toList();

    // Add any suggested size not already represented, unticked by default.
    for (final suggestion in suggestions) {
      final alreadyPresent = _rows.any(
        (row) => row.quantity == suggestion.quantity && row.unit == suggestion.unit && row.packageType == suggestion.packageType,
      );
      if (!alreadyPresent) {
        _rows.add(_VariantRow(
          quantity: suggestion.quantity,
          unit: suggestion.unit,
          packageType: suggestion.packageType,
          enabled: false,
        ));
      }
    }

    for (final row in _rows) {
      row.priceController.addListener(_refreshExample);
      row.quantityController.addListener(_refreshExample);
    }
  }

  void _refreshExample() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _addCustomSize() async {
    final quantityController = TextEditingController();
    String unit = widget.baseUnit;
    String packageType = 'BAG';

    final added = await showModalBottomSheet<bool>(
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
                    const Text('Add Custom Size', style: AppTextStyles.heading),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: kVariantUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (value) => setSheetState(() => unit = value ?? unit),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: packageType,
                      decoration: const InputDecoration(labelText: 'Package Type'),
                      items: kVariantPackageTypes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (value) => setSheetState(() => packageType = value ?? packageType),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(
                      label: 'Add Size',
                      onPressed: () {
                        final qty = double.tryParse(quantityController.text.trim());
                        if (qty == null || qty <= 0) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('Enter a valid quantity.')),
                          );
                          return;
                        }
                        Navigator.pop(sheetContext, true);
                        setState(() {
                          final row = _VariantRow(quantity: qty, unit: unit, packageType: packageType, enabled: true);
                          row.priceController.addListener(_refreshExample);
                          row.quantityController.addListener(_refreshExample);
                          _rows.add(row);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (added != true) {
      quantityController.dispose();
    }
  }

  Future<void> _toggleProductActive() async {
    try {
      await CustomerBusinessService.setProductActive(widget.productId, !_isProductActive);
      if (!mounted) return;
      setState(() => _isProductActive = !_isProductActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isProductActive ? 'Product activated.' : 'Product deactivated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update status: $error')));
    }
  }

  Future<void> _save() async {
    final enabledRows = _rows.where((row) => row.enabled).toList();
    if (enabledRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable at least one selling option.')),
      );
      return;
    }

    for (final row in enabledRows) {
      final price = double.tryParse(row.priceController.text.trim());
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid price for ${row.title}.')),
        );
        return;
      }
      if (row.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid quantity for ${row.title}.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      for (final row in _rows) {
        final price = double.tryParse(row.priceController.text.trim()) ?? 0;
        final moq = double.tryParse(row.moqController.text.trim()) ?? 1;
        final stock = double.tryParse(row.stockController.text.trim());
        final mrp = double.tryParse(row.mrpController.text.trim());
        final taxRate = double.tryParse(row.taxRateController.text.trim());
        final sku = row.skuController.text.trim().isEmpty ? null : row.skuController.text.trim();

        if (row.existingVariantId != null) {
          await CustomerBusinessService.updateVariant(
            variantId: row.existingVariantId!,
            quantity: row.quantity,
            unit: row.unit,
            packageType: row.packageType,
            sellingPrice: row.enabled ? price : null,
            minimumOrderQuantity: moq,
            stockQuantity: stock,
            mrp: mrp,
            taxRate: taxRate,
            sku: sku,
            isActive: row.enabled,
            notifyBusinessId: row.enabled ? widget.businessId : null,
            notifyProductName: widget.productName,
          );
        } else if (row.enabled) {
          await CustomerBusinessService.addVariant(
            productId: widget.productId,
            quantity: row.quantity,
            unit: row.unit,
            packageType: row.packageType,
            sellingPrice: price,
            minimumOrderQuantity: moq,
            stockQuantity: stock,
            mrp: mrp,
            taxRate: taxRate,
            sku: sku,
          );
        }
      }

      if (!_isEditing) {
        await CustomerBusinessService.notifyCustomersOfNewProduct(
          businessId: widget.businessId,
          productName: widget.productName,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save selling options: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [widget.category, widget.brand].where((v) => v != null && v.isNotEmpty).join(' • ');

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                children: [
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(widget.productName, style: AppTextStyles.heading, overflow: TextOverflow.ellipsis)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _isProductActive ? const Color(0xFFE1F7E8) : const Color(0xFFF0F0F0),
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                    ),
                                    child: Text(
                                      _isProductActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        color: _isProductActive ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (subtitleParts.isNotEmpty) Text(subtitleParts, style: AppTextStyles.bodyMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const Text('Selling Options', style: AppTextStyles.subheading),
                  const SizedBox(height: AppSpacing.md),
                  ..._rows.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: row.enabled,
                                    activeColor: AppColors.ownerPrimary,
                                    onChanged: (value) => setState(() => row.enabled = value ?? false),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row.title, style: AppTextStyles.subheading),
                                        Text(row.subtitle, style: AppTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (row.enabled) ...[
                                const SizedBox(height: AppSpacing.sm),
                                if (row.packageType != 'LOOSE')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    child: TextField(
                                      controller: row.quantityController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(labelText: '${row.packageType == 'BAG' ? 'Bag' : 'Pack'} Size (${row.unit})', isDense: true),
                                    ),
                                  ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: row.priceController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(labelText: 'Price per ${row.packageType == 'LOOSE' ? row.unit : row.packageType} (₹)', isDense: true),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    if (row.priceController.text.trim().isNotEmpty)
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: AppColors.ownerPrimary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(AppRadius.sm),
                                          ),
                                          child: Text(
                                            'Example\n₹${row.priceController.text.trim()} / ${row.label}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ownerPrimary),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: row.moqController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Min. order', isDense: true),
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
                                const SizedBox(height: AppSpacing.xs),
                                InkWell(
                                  onTap: () => setState(() => row.showAdvanced = !row.showAdvanced),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          row.showAdvanced ? 'Hide advanced settings' : 'More settings (MRP, tax, SKU)',
                                          style: const TextStyle(color: AppColors.ownerPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        Icon(
                                          row.showAdvanced ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                          size: 16,
                                          color: AppColors.ownerPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (row.showAdvanced) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: row.mrpController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(labelText: 'MRP (optional)', isDense: true),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: TextField(
                                          controller: row.taxRateController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(labelText: 'Tax % (optional)', isDense: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextField(
                                    controller: row.skuController,
                                    decoration: const InputDecoration(labelText: 'SKU (optional)', isDense: true),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      )),
                  AppSecondaryButton(
                    label: 'Add Custom Size',
                    icon: Icons.add,
                    onPressed: _addCustomSize,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: Column(
                children: [
                  if (_isEditing) ...[
                    AppSecondaryButton(
                      label: _isProductActive ? 'Deactivate Product' : 'Activate Product',
                      icon: _isProductActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onPressed: _saving ? null : _toggleProductActive,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppPrimaryButton(
                    label: _isEditing ? 'Update Product' : 'Save Product',
                    onPressed: _saving ? null : _save,
                    loading: _saving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

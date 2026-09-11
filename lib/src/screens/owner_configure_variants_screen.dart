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

List<_SuggestedSize> _suggestedSizesFor(String baseUnit) {
  switch (baseUnit) {
    case 'LTR':
    case 'ML':
      return const [
        _SuggestedSize(1, 'LTR', 'LOOSE'),
        _SuggestedSize(5, 'LTR', 'LOOSE'),
        _SuggestedSize(15, 'LTR', 'BOX'),
      ];
    case 'PCS':
      return const [
        _SuggestedSize(1, 'PCS', 'LOOSE'),
        _SuggestedSize(12, 'PCS', 'BOX'),
        _SuggestedSize(24, 'PCS', 'CARTON'),
      ];
    default:
      return const [
        _SuggestedSize(1, 'KG', 'LOOSE'),
        _SuggestedSize(5, 'KG', 'LOOSE'),
        _SuggestedSize(10, 'KG', 'LOOSE'),
        _SuggestedSize(25, 'KG', 'BAG'),
        _SuggestedSize(50, 'KG', 'BAG'),
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
    required this.quantity,
    required this.unit,
    required this.packageType,
    String? price,
    String? moq,
    String? stock,
    this.enabled = true,
  })  : priceController = TextEditingController(text: price ?? ''),
        moqController = TextEditingController(text: moq ?? '1'),
        stockController = TextEditingController(text: stock ?? '');

  final String? existingVariantId;
  double quantity;
  String unit;
  String packageType;
  bool enabled;
  final TextEditingController priceController;
  final TextEditingController moqController;
  final TextEditingController stockController;

  String get label {
    final qty = quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();
    final base = '$qty $unit';
    return packageType == 'LOOSE' ? base : '$base $packageType';
  }
}

/// Lets an owner pick which pack sizes they sell a product in and set each
/// one's own price -- deliberately never derives one price from another
/// (e.g. bag price is NOT quantity x loose price), since a wholesaler may
/// intentionally price a full bag below the per-kg rate.
class OwnerConfigureVariantsScreen extends StatefulWidget {
  const OwnerConfigureVariantsScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.businessId,
    this.baseUnit = 'KG',
    this.existingVariants = const <ProductVariant>[],
  });

  final String productId;
  final String productName;
  final String businessId;
  final String baseUnit;
  final List<ProductVariant> existingVariants;

  @override
  State<OwnerConfigureVariantsScreen> createState() => _OwnerConfigureVariantsScreenState();
}

class _OwnerConfigureVariantsScreenState extends State<OwnerConfigureVariantsScreen> {
  late List<_VariantRow> _rows;
  bool _saving = false;

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
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.priceController.dispose();
      row.moqController.dispose();
      row.stockController.dispose();
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
                          _rows.add(_VariantRow(quantity: qty, unit: unit, packageType: packageType, enabled: true));
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

  Future<void> _save() async {
    final enabledRows = _rows.where((row) => row.enabled).toList();
    if (enabledRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable at least one pack size.')),
      );
      return;
    }

    for (final row in enabledRows) {
      final price = double.tryParse(row.priceController.text.trim());
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid price for ${row.label}.')),
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

        if (row.existingVariantId != null) {
          await CustomerBusinessService.updateVariant(
            variantId: row.existingVariantId!,
            quantity: row.quantity,
            unit: row.unit,
            packageType: row.packageType,
            sellingPrice: row.enabled ? price : null,
            minimumOrderQuantity: moq,
            stockQuantity: stock,
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
          );
        }
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
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(widget.productName),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                children: [
                  const Text('How do you sell this product?', style: AppTextStyles.subheading),
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
                                  Expanded(child: Text(row.label, style: AppTextStyles.subheading)),
                                ],
                              ),
                              if (row.enabled) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: row.priceController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Selling Price (₹)', isDense: true),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: TextField(
                                        controller: row.moqController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Min. order', isDense: true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextField(
                                  controller: row.stockController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Stock (optional)', isDense: true),
                                ),
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
              child: AppPrimaryButton(
                label: 'Save',
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

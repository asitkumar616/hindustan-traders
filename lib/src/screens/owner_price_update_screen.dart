import 'package:flutter/material.dart';
import '../models/product_variant.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';

class _PriceRow {
  _PriceRow({required this.productName, required this.variant}) : price = variant.sellingPrice;
  final String productName;
  final ProductVariant variant;
  double price;
}

/// Fast bulk price editing: +/- Rs 10 steppers per variant, or tap the
/// amount to type an exact price. Nothing is written to product_variants
/// until the owner taps Save, so browsing away without saving discards
/// every change -- matches "Do NOT update the database until the owner
/// confirms Save."
class OwnerPriceUpdateScreen extends StatefulWidget {
  const OwnerPriceUpdateScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerPriceUpdateScreen> createState() => _OwnerPriceUpdateScreenState();
}

class _OwnerPriceUpdateScreenState extends State<OwnerPriceUpdateScreen> {
  bool _loading = true;
  bool _saving = false;
  List<_PriceRow> _rows = const <_PriceRow>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await CustomerBusinessService.getProductsForBusiness(widget.businessId);
      final rows = <_PriceRow>[];
      for (final product in products) {
        final name = product['name']?.toString() ?? 'Product';
        final variants = (product['variants'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ProductVariant.fromMap);
        for (final variant in variants) {
          rows.add(_PriceRow(productName: name, variant: variant));
        }
      }
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load prices: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editExactPrice(_PriceRow row) async {
    final controller = TextEditingController(text: row.price.toStringAsFixed(0));
    final newPrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${row.productName} – ${row.variant.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (newPrice != null && newPrice > 0) {
      setState(() => row.price = newPrice);
    }
  }

  bool get _hasChanges => _rows.any((row) => row.price != row.variant.sellingPrice);

  Future<void> _save() async {
    final changed = _rows.where((row) => row.price != row.variant.sellingPrice).toList();
    if (changed.isEmpty) return;

    setState(() => _saving = true);
    try {
      for (final row in changed) {
        await CustomerBusinessService.updateVariant(
          variantId: row.variant.id,
          sellingPrice: row.price,
          notifyBusinessId: widget.businessId,
          notifyProductName: row.productName,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${changed.length} price${changed.length == 1 ? '' : 's'}.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save prices: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Price Update'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const AppLoadingState()
                  : _rows.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.sell_outlined,
                          title: 'No Prices Yet',
                          message: 'Add products with selling variants first.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            final changed = row.price != row.variant.sellingPrice;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${row.productName} – ${row.variant.label}', style: AppTextStyles.subheading),
                                          const SizedBox(height: 2),
                                          InkWell(
                                            onTap: () => _editExactPrice(row),
                                            child: Text(
                                              '₹${formatIndianAmount(row.price)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18,
                                                color: changed ? AppColors.ownerPrimary : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StepButton(
                                      icon: Icons.remove_rounded,
                                      onTap: () => setState(() => row.price = (row.price - 10).clamp(0, double.infinity)),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    _StepButton(
                                      icon: Icons.add_rounded,
                                      onTap: () => setState(() => row.price = row.price + 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                child: AppPrimaryButton(
                  label: 'Save Changes',
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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Icon(icon, size: 18, color: AppColors.ownerPrimary),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/master_product.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_primary_button.dart';
import 'owner_configure_variants_screen.dart';

/// "+ Create Custom Product" -- for anything not in the shared master
/// catalog. Creates a business-scoped product (master_product_id left null)
/// and then hands off to the same variant configuration screen the catalog
/// flow uses, so both paths end up with identically-shaped selling options.
class OwnerCustomProductScreen extends StatefulWidget {
  const OwnerCustomProductScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerCustomProductScreen> createState() => _OwnerCustomProductScreenState();
}

class _OwnerCustomProductScreenState extends State<OwnerCustomProductScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  String _category = kMasterProductCategories.last;
  String _baseUnit = 'KG';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name is required.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final created = await CustomerBusinessService.createCustomProduct(
        businessId: widget.businessId,
        name: name,
        baseUnit: _baseUnit,
        category: _category,
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
      );
      if (!mounted || created == null) return;

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerConfigureVariantsScreen(
            productId: created['id']?.toString() ?? '',
            productName: created['name']?.toString() ?? name,
            businessId: widget.businessId,
            baseUnit: _baseUnit,
          ),
        ),
      );

      if (!mounted) return;
      if (saved == true) {
        Navigator.pop(context, true);
      } else {
        setState(() => _saving = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create product: $error')),
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
        title: const Text('Create Custom Product'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: kMasterProductCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Brand (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _baseUnit,
              decoration: const InputDecoration(labelText: 'Base Unit'),
              items: kVariantUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (value) => setState(() => _baseUnit = value ?? _baseUnit),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'Continue to Selling Options',
              onPressed: _saving ? null : _continue,
              loading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

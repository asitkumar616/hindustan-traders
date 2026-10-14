import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_category.dart';
import '../models/master_product.dart';
import '../services/admin_catalog_service.dart';
import '../services/category_service.dart';
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
import '../widgets/image_source_sheet.dart';
import 'admin_catalog_import_screen.dart';

/// Admin "Master Catalog Management" -- the global product list every
/// owner's Add-from-Catalog screen reads from. Add/edit here never
/// touches an owner's own `products` row; existing owner products keep
/// their copied name/image/category even if this entry later changes
/// (see customer_business_service.dart's createProductFromMasterProduct).
class AdminMasterCatalogScreen extends StatefulWidget {
  const AdminMasterCatalogScreen({super.key});

  @override
  State<AdminMasterCatalogScreen> createState() => _AdminMasterCatalogScreenState();
}

class _AdminMasterCatalogScreenState extends State<AdminMasterCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _category = 'All';
  bool _loading = true;
  List<MasterProduct> _products = const <MasterProduct>[];
  List<CatalogCategory> _categories = const <CatalogCategory>[];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await CategoryService.fetchTopLevel();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await AdminCatalogService.fetchMasterProducts(
        categoryName: _category == 'All' ? null : _category,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _products = products);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load catalog: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(MasterProduct product) async {
    try {
      await AdminCatalogService.setMasterProductActive(product.id, !product.isActive);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update: $error')));
    }
  }

  Future<void> _openForm({MasterProduct? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _MasterProductForm(existing: existing, categories: _categories),
    );
    if (saved == true) await _load();
  }

  Future<void> _openImport() async {
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminCatalogImportScreen()),
    );
    if (imported == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ..._categories.map((c) => c.name)];

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Master Catalog'),
        actions: [
          IconButton(onPressed: _openImport, icon: const Icon(Icons.upload_file_outlined), tooltip: 'Bulk Import (CSV)'),
          IconButton(onPressed: () => _openForm(), icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search product, brand, or category...',
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
                    selectedColor: AppColors.adminPrimary,
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
                            AppEmptyState(icon: Icons.inventory_2_outlined, title: 'No Products', message: 'Tap + to add one, or import a CSV.'),
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
                                onTap: () => _openForm(existing: product),
                                child: Row(
                                  children: [
                                    CatalogProductImage(
                                      productName: product.productName,
                                      category: product.category,
                                      imageUrl: product.imageUrl,
                                      size: 56,
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.productName, style: product.isActive ? AppTextStyles.subheading : AppTextStyles.bodyMuted),
                                          Text(
                                            [product.category, if (product.brand?.isNotEmpty == true) product.brand].join(' · '),
                                            style: AppTextStyles.caption,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: product.isActive,
                                      activeTrackColor: AppColors.adminPrimary,
                                      onChanged: (_) => _toggleActive(product),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecRow {
  _SpecRow({String? key, String? value})
      : keyController = TextEditingController(text: key ?? ''),
        valueController = TextEditingController(text: value ?? '');

  final TextEditingController keyController;
  final TextEditingController valueController;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class _MasterProductForm extends StatefulWidget {
  const _MasterProductForm({required this.existing, required this.categories});

  final MasterProduct? existing;
  final List<CatalogCategory> categories;

  @override
  State<_MasterProductForm> createState() => _MasterProductFormState();
}

class _MasterProductFormState extends State<_MasterProductForm> {
  late final _nameController = TextEditingController(text: widget.existing?.productName ?? '');
  late final _brandController = TextEditingController(text: widget.existing?.brand ?? '');
  late final _imageUrlController = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late String _baseUnit = kVariantUnits.contains(widget.existing?.baseUnit) ? widget.existing!.baseUnit : 'KG';
  CatalogCategory? _selectedCategory;
  List<CatalogCategory> _subcategories = const <CatalogCategory>[];
  CatalogCategory? _selectedSubcategory;
  final List<_SpecRow> _specRows = [];
  File? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existingCategoryId = widget.existing?.categoryId;
    if (existingCategoryId != null) {
      final matches = widget.categories.where((c) => c.id == existingCategoryId);
      _selectedCategory = matches.isEmpty ? null : matches.first;
      if (_selectedCategory != null) _loadSubcategories(_selectedCategory!.id, preselectId: widget.existing?.subcategoryId);
    }
    final specs = widget.existing?.specifications;
    if (specs != null) {
      for (final entry in specs.entries) {
        _specRows.add(_SpecRow(key: entry.key, value: entry.value?.toString()));
      }
    }
  }

  Future<void> _loadSubcategories(String categoryId, {String? preselectId}) async {
    final subcategories = await CategoryService.fetchSubcategories(categoryId);
    if (!mounted) return;
    setState(() {
      _subcategories = subcategories;
      final matches = subcategories.where((c) => c.id == preselectId);
      _selectedSubcategory = matches.isEmpty ? null : matches.first;
    });
  }

  Future<void> _pickImage() async {
    final picked = await pickProductImageWithPreview(context);
    if (picked == null || !mounted) return;
    setState(() => _pickedImage = picked);
  }

  void _removeImage() => setState(() {
        _pickedImage = null;
        _imageUrlController.clear();
      });

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _imageUrlController.dispose();
    for (final row in _specRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product name is required.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final duplicate = await AdminCatalogService.isDuplicateMasterProduct(
        productName: name,
        brand: _brandController.text.trim(),
        category: _selectedCategory?.name,
        excludeId: widget.existing?.id,
      );
      if (duplicate) {
        if (!mounted) return;
        setState(() => _saving = false);
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Possible Duplicate'),
            content: Text('A product named "$name" with the same brand and category already exists. Add it anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add Anyway')),
            ],
          ),
        );
        if (proceed != true) return;
        setState(() => _saving = true);
      }

      String? imageUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();
      final pickedImage = _pickedImage;
      if (pickedImage != null) {
        final client = Supabase.instance.client;
        final extension = pickedImage.path.contains('.') ? pickedImage.path.split('.').last.toLowerCase() : 'jpg';
        final path = '${DateTime.now().millisecondsSinceEpoch}.$extension';
        await client.storage.from('master-catalog-images').upload(path, pickedImage, fileOptions: const FileOptions(upsert: true));
        imageUrl = client.storage.from('master-catalog-images').getPublicUrl(path);
      }

      final specifications = <String, dynamic>{};
      for (final row in _specRows) {
        final key = row.keyController.text.trim();
        final value = row.valueController.text.trim();
        if (key.isNotEmpty && value.isNotEmpty) specifications[key] = value;
      }

      await AdminCatalogService.upsertMasterProduct(
        id: widget.existing?.id,
        productName: name,
        category: _selectedCategory?.name,
        categoryId: _selectedCategory?.id,
        subcategoryId: _selectedSubcategory?.id,
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        imageUrl: imageUrl,
        baseUnit: _baseUnit,
        specifications: specifications.isEmpty ? null : specifications,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? 'Edit Catalog Product' : 'Add Catalog Product', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 80,
                          height: 80,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.adminPrimary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: _pickedImage != null
                              ? Image.file(_pickedImage!, fit: BoxFit.cover)
                              : _imageUrlController.text.trim().isNotEmpty
                                  ? Image.network(_imageUrlController.text.trim(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: AppColors.adminPrimary))
                                  : const Icon(Icons.add_a_photo_outlined, color: AppColors.adminPrimary),
                        ),
                      ),
                      if (_pickedImage != null || _imageUrlController.text.trim().isNotEmpty)
                        Positioned(
                          top: -8,
                          right: -8,
                          child: InkWell(
                            onTap: _removeImage,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Image URL (optional, or tap photo to upload)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory?.id,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (value) {
                  final matches = widget.categories.where((c) => c.id == value);
                  if (matches.isEmpty) return;
                  setState(() => _selectedCategory = matches.first);
                  _loadSubcategories(matches.first.id);
                },
              ),
              if (_subcategories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubcategory?.id,
                  decoration: const InputDecoration(labelText: 'Subcategory (Optional)'),
                  items: _subcategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (value) {
                    final matches = _subcategories.where((c) => c.id == value);
                    setState(() => _selectedSubcategory = matches.isEmpty ? null : matches.first);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(controller: _brandController, decoration: const InputDecoration(labelText: 'Brand (Optional)')),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _baseUnit,
                decoration: const InputDecoration(labelText: 'Base Unit'),
                items: kVariantUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (value) => setState(() => _baseUnit = value ?? _baseUnit),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Text('Specifications', style: AppTextStyles.subheading)),
                  TextButton.icon(
                    onPressed: () => setState(() => _specRows.add(_SpecRow())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              ..._specRows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: row.keyController, decoration: const InputDecoration(labelText: 'Attribute', isDense: true))),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: TextField(controller: row.valueController, decoration: const InputDecoration(labelText: 'Value', isDense: true))),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() {
                            row.dispose();
                            _specRows.remove(row);
                          }),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: widget.existing != null ? 'Save Changes' : 'Add to Catalog',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

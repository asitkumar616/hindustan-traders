import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/catalog_category.dart';
import '../models/master_product.dart';
import '../models/voice_product_draft.dart';
import '../services/category_service.dart';
import '../services/customer_business_service.dart';
import '../services/voice_product_parser.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_primary_button.dart';
import 'owner_configure_variants_screen.dart';

/// "Add Manually" -- for anything not in the shared master catalog. Creates
/// a business-scoped product (master_product_id left null) and then hands
/// off to the same variant configuration screen the catalog flow uses, so
/// both paths end up with identically-shaped selling options.
class OwnerCustomProductScreen extends StatefulWidget {
  const OwnerCustomProductScreen({super.key, required this.businessId, this.initialDraft});

  final String businessId;

  /// Pre-fills name/unit from a spoken "add product" draft (Ask Assistant
  /// deep link). Price isn't collected here -- the owner sets it on the
  /// next screen (Selling Options) like every other product.
  final VoiceProductDraft? initialDraft;

  @override
  State<OwnerCustomProductScreen> createState() => _OwnerCustomProductScreenState();
}

class _OwnerCustomProductScreenState extends State<OwnerCustomProductScreen> {
  late final _nameController = TextEditingController(text: widget.initialDraft?.name ?? '');
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  List<CatalogCategory> _categories = const <CatalogCategory>[];
  List<CatalogCategory> _subcategories = const <CatalogCategory>[];
  CatalogCategory? _selectedCategory;
  CatalogCategory? _selectedSubcategory;
  late String _baseUnit = _matchBaseUnit(widget.initialDraft?.unit);
  bool _saving = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await CategoryService.fetchTopLevel();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selectedCategory = categories.isEmpty ? null : categories.first;
    });
    final selected = _selectedCategory;
    if (selected != null) _loadSubcategories(selected.id);
  }

  Future<void> _loadSubcategories(String categoryId) async {
    final subcategories = await CategoryService.fetchSubcategories(categoryId);
    if (!mounted) return;
    setState(() {
      _subcategories = subcategories;
      _selectedSubcategory = null;
    });
  }

  static String _matchBaseUnit(String? spokenUnit) {
    if (spokenUnit == null || spokenUnit.trim().isEmpty) return 'KG';
    final upper = spokenUnit.trim().toUpperCase();
    return kVariantUnits.contains(upper) ? upper : 'KG';
  }

  @override
  void dispose() {
    _speech.stop();
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceFill() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    final permission = await Permission.microphone.request();
    if (!mounted) return;
    if (permission.isDenied || permission.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied.')));
      return;
    }

    final available = _speech.isAvailable || await _speech.initialize();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speech recognition unavailable.')));
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted || !result.finalResult) return;
        final draft = VoiceProductParser.parse(result.recognizedWords);
        setState(() {
          _listening = false;
          if (draft.name != null && draft.name!.isNotEmpty) _nameController.text = draft.name!;
          if (draft.unit != null) _baseUnit = _matchBaseUnit(draft.unit);
        });
      },
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
    );
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
        category: _selectedCategory?.name,
        categoryId: _selectedCategory?.id,
        subcategoryId: _selectedSubcategory?.id,
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
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
        title: const Text('Add Product'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const Text('Product Information', style: AppTextStyles.subheading),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.ownerPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, color: AppColors.ownerPrimary),
                      SizedBox(height: 4),
                      Text('Photo', style: AppTextStyles.caption, textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'e.g. Kohinoor Rice',
                          suffixIcon: IconButton(
                            onPressed: _toggleVoiceFill,
                            icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded),
                            color: _listening ? AppColors.danger : AppColors.ownerPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Photo shown to customers is chosen automatically from the product name and category.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory?.id,
              decoration: const InputDecoration(labelText: 'Category *'),
              items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (value) {
                final matches = _categories.where((c) => c.id == value);
                if (matches.isEmpty) return;
                final category = matches.first;
                setState(() => _selectedCategory = category);
                _loadSubcategories(category.id);
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
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Brand (Optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _baseUnit,
              decoration: const InputDecoration(labelText: 'Base Unit'),
              items: kVariantUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (value) => setState(() => _baseUnit = value ?? _baseUnit),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Additional Details', style: AppTextStyles.subheading),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description / Notes (Optional)',
                hintText: 'Product description, quality, etc...',
                alignLabelWithHint: true,
              ),
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

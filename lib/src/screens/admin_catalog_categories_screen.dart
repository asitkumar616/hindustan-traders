import 'package:flutter/material.dart';
import '../models/catalog_category.dart';
import '../services/admin_catalog_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';

/// Admin "Category Management" -- add/rename/reorder/deactivate the
/// shared category tree every owner's "What does your business sell?"
/// and Add-from-Catalog screens read from. Never hard-deletes a category
/// (it may already be referenced by master_products/products) --
/// deactivating just hides it from new selections.
class AdminCatalogCategoriesScreen extends StatefulWidget {
  const AdminCatalogCategoriesScreen({super.key});

  @override
  State<AdminCatalogCategoriesScreen> createState() => _AdminCatalogCategoriesScreenState();
}

class _AdminCatalogCategoriesScreenState extends State<AdminCatalogCategoriesScreen> {
  bool _loading = true;
  List<CatalogCategory> _all = const <CatalogCategory>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final categories = await AdminCatalogService.fetchAllCategories();
      if (!mounted) return;
      setState(() => _all = categories);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load categories: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CatalogCategory> get _topLevel => _all.where((c) => c.parentId == null).toList();
  List<CatalogCategory> _childrenOf(String id) => _all.where((c) => c.parentId == id).toList();

  Future<void> _openForm({CatalogCategory? existing, String? parentId}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final orderController = TextEditingController(text: (existing?.displayOrder ?? 0).toString());
    bool saving = false;

    await showModalBottomSheet<void>(
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
                    Text(
                      existing != null
                          ? 'Edit Category'
                          : parentId != null
                              ? 'Add Subcategory'
                              : 'Add Category',
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Category Name *'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Display Order'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(
                      label: existing != null ? 'Save Changes' : 'Add Category',
                      loading: saving,
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(content: Text('Category name is required.')),
                                );
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                await AdminCatalogService.upsertCategory(
                                  id: existing?.id,
                                  name: name,
                                  parentId: existing?.parentId ?? parentId,
                                  displayOrder: int.tryParse(orderController.text.trim()) ?? 0,
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                              } catch (error) {
                                setSheetState(() => saving = false);
                                if (!sheetContext.mounted) return;
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text('Unable to save: $error')),
                                );
                              }
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

    nameController.dispose();
    orderController.dispose();
    await _load();
  }

  Future<void> _toggleActive(CatalogCategory category) async {
    try {
      await AdminCatalogService.setCategoryActive(category.id, !category.isActive);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update: $error')));
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
        title: const Text('Category Management'),
        actions: [
          IconButton(onPressed: () => _openForm(), icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingState()
            : _topLevel.isEmpty
                ? const AppEmptyState(icon: Icons.category_outlined, title: 'No Categories', message: 'Tap + to add your first category.')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                      itemCount: _topLevel.length,
                      itemBuilder: (context, index) {
                        final category = _topLevel[index];
                        final children = _childrenOf(category.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                            child: ExpansionTile(
                              title: _CategoryRow(category: category, onEdit: () => _openForm(existing: category), onToggle: () => _toggleActive(category)),
                              children: [
                                ...children.map(
                                  (sub) => Padding(
                                    padding: const EdgeInsets.only(left: AppSpacing.lg),
                                    child: _CategoryRow(
                                      category: sub,
                                      onEdit: () => _openForm(existing: sub),
                                      onToggle: () => _toggleActive(sub),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.md, AppSpacing.sm),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _openForm(parentId: category.id),
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: const Text('Add Subcategory'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onEdit, required this.onToggle});

  final CatalogCategory category;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            category.name,
            style: category.isActive ? AppTextStyles.body : AppTextStyles.bodyMuted,
          ),
        ),
        if (!category.isActive)
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: const Text('Inactive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
        IconButton(
          icon: Icon(category.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
          onPressed: onToggle,
        ),
      ],
    );
  }
}

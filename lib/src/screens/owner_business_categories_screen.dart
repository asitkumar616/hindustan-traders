import 'package:flutter/material.dart';
import '../models/catalog_category.dart';
import '../services/category_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';

/// "What does your business sell?" -- lets an owner pick which top-level
/// categories their shop deals in. The selection drives which category
/// chips show by default in Add-from-Catalog; it is never permanent -- an
/// owner can return here any time via "+ Category" to add more later.
class OwnerBusinessCategoriesScreen extends StatefulWidget {
  const OwnerBusinessCategoriesScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerBusinessCategoriesScreen> createState() => _OwnerBusinessCategoriesScreenState();
}

class _OwnerBusinessCategoriesScreenState extends State<OwnerBusinessCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<CatalogCategory> _categories = const <CatalogCategory>[];
  Set<String> _selected = <String>{};

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
    final categories = await CategoryService.fetchTopLevel();
    final selected = await CategoryService.fetchBusinessCategoryIds(widget.businessId);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selected = selected;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await CategoryService.saveBusinessCategories(widget.businessId, _selected);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save categories: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _categories
        : _categories.where((c) => c.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('What does your business sell?'),
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingState()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search categories...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(child: Text('No matching categories.', style: AppTextStyles.bodyMuted))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final category = visible[index];
                              final checked = _selected.contains(category.id);
                              return CheckboxListTile(
                                value: checked,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.ownerPrimary,
                                title: Text(category.name, style: AppTextStyles.body),
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(category.id);
                                  } else {
                                    _selected.remove(category.id);
                                  }
                                }),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                    child: AppPrimaryButton(
                      label: 'Save Categories',
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

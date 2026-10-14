import 'package:flutter/material.dart';
import '../models/catalog_category.dart';
import '../services/admin_catalog_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_primary_button.dart';

/// Admin's "Business Categories" picker (Add/Edit Owner) -- one required
/// Primary category plus any number of optional Additional categories,
/// searchable. Returns null if the admin cancels without saving.
Future<OwnerCategorySelection?> showBusinessCategoryPickerSheet(
  BuildContext context, {
  required List<CatalogCategory> categories,
  required OwnerCategorySelection initial,
}) {
  return showModalBottomSheet<OwnerCategorySelection>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => _BusinessCategoryPickerSheet(categories: categories, initial: initial),
  );
}

class _BusinessCategoryPickerSheet extends StatefulWidget {
  const _BusinessCategoryPickerSheet({required this.categories, required this.initial});

  final List<CatalogCategory> categories;
  final OwnerCategorySelection initial;

  @override
  State<_BusinessCategoryPickerSheet> createState() => _BusinessCategoryPickerSheetState();
}

class _BusinessCategoryPickerSheetState extends State<_BusinessCategoryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String? _primaryId;
  late Set<String> _additionalIds;

  @override
  void initState() {
    super.initState();
    _primaryId = widget.initial.primaryCategoryId;
    _additionalIds = {...widget.initial.additionalCategoryIds};
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isIncluded(String id) => id == _primaryId || _additionalIds.contains(id);

  void _toggleIncluded(String id) {
    setState(() {
      if (_isIncluded(id)) {
        _additionalIds.remove(id);
        if (_primaryId == id) {
          // Promote the first remaining selection to primary, if any.
          _primaryId = _additionalIds.isEmpty ? null : _additionalIds.first;
          if (_primaryId != null) _additionalIds.remove(_primaryId);
        }
      } else if (_primaryId == null) {
        _primaryId = id;
      } else {
        _additionalIds.add(id);
      }
    });
  }

  void _makePrimary(String id) {
    setState(() {
      if (_primaryId != null && _primaryId != id) _additionalIds.add(_primaryId!);
      _additionalIds.remove(id);
      _primaryId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.categories
        : widget.categories.where((c) => c.name.toLowerCase().contains(query)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Business Categories', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Pick one Primary category (required) and any Additional categories this business also sells.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: 'Search categories...', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: visible.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text('No matching categories.', style: AppTextStyles.bodyMuted),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final category = visible[index];
                        final included = _isIncluded(category.id);
                        final isPrimary = category.id == _primaryId;
                        return CheckboxListTile(
                          value: included,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.adminPrimary,
                          onChanged: (_) => _toggleIncluded(category.id),
                          title: Text(category.name, style: AppTextStyles.body),
                          secondary: !included
                              ? null
                              : TextButton.icon(
                                  onPressed: isPrimary ? null : () => _makePrimary(category.id),
                                  icon: Icon(isPrimary ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: isPrimary ? AppColors.primary : AppColors.textSecondary),
                                  label: Text(isPrimary ? 'Primary' : 'Set Primary', style: TextStyle(fontSize: 11.5, color: isPrimary ? AppColors.primary : AppColors.textSecondary)),
                                ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: 'Save Selection',
              onPressed: _primaryId == null
                  ? null
                  : () => Navigator.pop(
                        context,
                        OwnerCategorySelection(primaryCategoryId: _primaryId, additionalCategoryIds: _additionalIds),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/catalog_category.dart';
import '../models/master_product.dart';
import '../services/admin_catalog_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';

enum _RowStatus { valid, error }

class _ImportRow {
  _ImportRow({required this.rowNumber, required this.status, required this.issues, this.payload, this.preview = ''});

  final int rowNumber;
  final _RowStatus status;
  final List<String> issues;
  final Map<String, dynamic>? payload;
  final String preview;
}

/// Admin bulk CSV import for the master catalog -- expected columns:
/// category, subcategory, product_name, brand, image_url, base_unit,
/// specifications (a JSON object in one cell, optional). pack_size/
/// pack_unit/default_mrp are deliberately NOT stored here: pricing and
/// pack size are always per-owner (product_variants), never part of the
/// shared catalog, so those columns (if present) are ignored.
///
/// Validates every row before anything touches the database -- only rows
/// with zero issues are counted into "Import N Products"; rows with a
/// warning or error are shown but excluded, so a bad file can never
/// half-import silently (per the spec this was built against).
class AdminCatalogImportScreen extends StatefulWidget {
  const AdminCatalogImportScreen({super.key});

  @override
  State<AdminCatalogImportScreen> createState() => _AdminCatalogImportScreenState();
}

class _AdminCatalogImportScreenState extends State<AdminCatalogImportScreen> {
  bool _busy = false;
  String? _fileName;
  List<_ImportRow> _rows = const <_ImportRow>[];

  List<_ImportRow> get _validRows => _rows.where((r) => r.status == _RowStatus.valid).toList();

  Future<void> _pickAndValidate() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv']);
    if (file == null) return;

    setState(() {
      _busy = true;
      _fileName = file.name;
      _rows = const <_ImportRow>[];
    });

    try {
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);
      final table = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
      if (table.isEmpty) throw Exception('File is empty.');

      final header = table.first.map((c) => c.toString().trim().toLowerCase()).toList();
      int col(String name) => header.indexOf(name);
      final iCategory = col('category');
      final iSubcategory = col('subcategory');
      final iName = col('product_name');
      final iBrand = col('brand');
      final iImageUrl = col('image_url');
      final iBaseUnit = col('base_unit');
      final iSpecifications = col('specifications');

      final allCategories = await AdminCatalogService.fetchAllCategories();
      final topLevelByName = <String, CatalogCategory>{
        for (final c in allCategories.where((c) => c.parentId == null)) c.name.toLowerCase(): c,
      };
      final seenInFile = <String>{};

      final rows = <_ImportRow>[];
      for (var r = 1; r < table.length; r++) {
        final raw = table[r];
        if (raw.every((cell) => cell.toString().trim().isEmpty)) continue;

        String cell(int index) => index >= 0 && index < raw.length ? raw[index].toString().trim() : '';
        final issues = <String>[];

        final name = cell(iName);
        if (name.isEmpty) issues.add('Missing product_name');

        final categoryName = cell(iCategory);
        CatalogCategory? category;
        if (categoryName.isEmpty) {
          issues.add('Missing category');
        } else {
          category = topLevelByName[categoryName.toLowerCase()];
          if (category == null) issues.add('Unknown category "$categoryName"');
        }

        final subcategoryName = cell(iSubcategory);
        CatalogCategory? subcategory;
        if (subcategoryName.isNotEmpty && category != null) {
          final matches = allCategories.where((c) => c.parentId == category!.id && c.name.toLowerCase() == subcategoryName.toLowerCase());
          if (matches.isEmpty) {
            issues.add('Unknown subcategory "$subcategoryName" for $categoryName');
          } else {
            subcategory = matches.first;
          }
        }

        var baseUnit = cell(iBaseUnit).toUpperCase();
        if (baseUnit.isEmpty) {
          baseUnit = 'KG';
        } else if (!kVariantUnits.contains(baseUnit)) {
          issues.add('Unrecognized base_unit "$baseUnit"');
        }

        final brand = cell(iBrand);
        final imageUrl = cell(iImageUrl);

        Map<String, dynamic>? specifications;
        final specsText = cell(iSpecifications);
        if (specsText.isNotEmpty) {
          try {
            final decoded = jsonDecode(specsText);
            if (decoded is Map<String, dynamic>) {
              specifications = decoded;
            } else {
              issues.add('specifications is not a JSON object');
            }
          } catch (_) {
            issues.add('specifications is not valid JSON');
          }
        }

        final dedupeKey = '${name.toLowerCase()}|${brand.toLowerCase()}|${categoryName.toLowerCase()}';
        if (name.isNotEmpty && !seenInFile.add(dedupeKey)) {
          issues.add('Duplicate of an earlier row in this file');
        }

        final payload = issues.isEmpty
            ? {
                'product_name': name,
                'category': category?.name,
                'category_id': category?.id,
                'subcategory_id': subcategory?.id,
                'brand': brand.isEmpty ? null : brand,
                'image_url': imageUrl.isEmpty ? null : imageUrl,
                'base_unit': baseUnit,
                'specifications': specifications,
              }
            : null;

        rows.add(_ImportRow(
          rowNumber: r + 1,
          status: issues.isEmpty ? _RowStatus.valid : _RowStatus.error,
          issues: issues,
          payload: payload,
          preview: name.isEmpty ? '(row ${r + 1})' : name,
        ));
      }

      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to read file: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final valid = _validRows;
    if (valid.isEmpty) return;

    setState(() => _busy = true);
    try {
      final count = await AdminCatalogService.bulkImportMasterProducts(
        valid.map((r) => r.payload!).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count products.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _rows.where((r) => r.status == _RowStatus.valid).length;
    final errors = _rows.where((r) => r.status == _RowStatus.error).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Bulk Import (CSV)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Columns: category, subcategory, product_name, brand, image_url, base_unit, specifications (JSON, optional). '
                    'pack_size/pack_unit/default_mrp are not part of the shared catalog -- owners set price/pack size when they add a product to their shop.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickAndValidate,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_fileName ?? 'Select CSV File'),
                  ),
                  if (_rows.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${_rows.length} rows detected  ·  Valid: $valid  ·  Needs Review: $errors',
                      style: AppTextStyles.subheading,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _busy
                  ? const AppLoadingState()
                  : _rows.isEmpty
                      ? const AppEmptyState(icon: Icons.table_chart_outlined, title: 'No File Selected', message: 'Select a CSV file to preview and validate it.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            final isValid = row.status == _RowStatus.valid;
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: isValid ? const Color(0xFFE1F7E8) : const Color(0xFFFFEAEA),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isValid ? Icons.check_circle_outline : Icons.error_outline,
                                    size: 18,
                                    color: isValid ? const Color(0xFF2E7D32) : AppColors.danger,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Row ${row.rowNumber}: ${row.preview}', style: AppTextStyles.body),
                                        if (row.issues.isNotEmpty)
                                          Text(row.issues.join('; '), style: AppTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            if (valid > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                child: AppPrimaryButton(
                  label: 'Import $valid Product${valid == 1 ? '' : 's'}',
                  loading: _busy,
                  onPressed: _busy ? null : _import,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

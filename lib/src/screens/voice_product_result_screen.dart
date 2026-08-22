import 'package:flutter/material.dart';
import '../models/voice_product_draft.dart';
import '../services/customer_business_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_secondary_button.dart';

class VoiceProductResultScreen extends StatefulWidget {
  const VoiceProductResultScreen({super.key, required this.businessId, required this.draft});

  final String businessId;
  final VoiceProductDraft draft;

  @override
  State<VoiceProductResultScreen> createState() => _VoiceProductResultScreenState();
}

class _VoiceProductResultScreenState extends State<VoiceProductResultScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;
  bool _editing = false;
  bool _saving = false;

  bool get _understood => widget.draft.name?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name ?? '');
    _unitController = TextEditingController(text: widget.draft.unit ?? 'kg');
    _priceController = TextEditingController(text: widget.draft.price?.toStringAsFixed(0) ?? '0');
    _editing = !_understood;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product name is required.')));
      setState(() => _editing = true);
      return;
    }

    setState(() => _saving = true);
    try {
      final unit = _unitController.text.trim().isEmpty ? 'unit' : _unitController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      await CustomerBusinessService.createProduct(
        businessId: widget.businessId,
        name: name,
        unit: unit,
        price: price,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save product: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xl, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                  const Expanded(child: Text('Voice Result', style: AppTextStyles.heading)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _understood ? const Color(0xFFE1F7E8) : const Color(0xFFFFF1DC),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _understood ? Icons.check_circle_rounded : Icons.info_rounded,
                            color: _understood ? const Color(0xFF2E7D32) : const Color(0xFFC9820A),
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _understood ? 'We understood this' : "We couldn't catch everything -- please review and edit below.",
                              style: TextStyle(
                                color: _understood ? const Color(0xFF2E7D32) : const Color(0xFFC9820A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _FieldCard(label: 'Product Name', controller: _nameController, editable: _editing),
                    const SizedBox(height: AppSpacing.md),
                    _FieldCard(label: 'Unit', controller: _unitController, editable: _editing),
                    const SizedBox(height: AppSpacing.md),
                    _FieldCard(
                      label: 'Price (₹)',
                      controller: _priceController,
                      editable: _editing,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: _editing ? 'Done' : 'Edit',
                      onPressed: _saving ? null : () => setState(() => _editing = !_editing),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Confirm & Save',
                      onPressed: _saving ? null : _save,
                      loading: _saving,
                    ),
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

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.controller,
    required this.editable,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool editable;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodyMuted),
          const SizedBox(height: 4),
          editable
              ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                )
              : Text(
                  controller.text.isEmpty ? 'Not detected' : controller.text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: controller.text.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
        ],
      ),
    );
  }
}

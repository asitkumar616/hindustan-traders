import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_primary_button.dart';
import 'app_secondary_button.dart';

/// "Add Product Image" flow: a Material 3 bottom sheet offering Take
/// Photo / Choose from Gallery / Cancel, then a preview-before-save step.
/// Returns the picked [File], or null if the user cancelled at any point
/// or the pick failed (a SnackBar explains why in that case).
///
/// Images are resized/compressed at pick time (imageQuality + maxWidth/
/// maxHeight) via the existing image_picker dependency -- no separate
/// image-processing package needed, and gallery/camera pickers already
/// only return image files, so no extra file-type validation is needed.
Future<File?> pickProductImageWithPreview(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => const _ImageSourceSheet(),
  );
  if (source == null || !context.mounted) return null;

  if (source == ImageSource.camera) {
    final status = await Permission.camera.request();
    if (!context.mounted) return null;
    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied. Enable it from device Settings to take photos.')),
      );
      return null;
    }
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to take a photo.')),
      );
      return null;
    }
  }

  XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
      maxHeight: 1600,
    );
  } catch (error) {
    if (!context.mounted) return null;
    final message = source == ImageSource.camera
        ? 'Camera is unavailable right now.'
        : 'Unable to open gallery.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$message ($error)')));
    return null;
  }

  if (picked == null) return null; // user cancelled the native picker
  final file = File(picked.path);

  if (!context.mounted) return null;
  final confirmed = await _showPreview(context, file);
  return confirmed == true ? file : null;
}

Future<bool?> _showPreview(BuildContext context, File file) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Use this photo?', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.file(file, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Retake',
                    onPressed: () => Navigator.pop(sheetContext, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Use Photo',
                    onPressed: () => Navigator.pop(sheetContext, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Product Image', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.md),
            _SourceTile(
              icon: Icons.photo_camera_rounded,
              label: 'Take Photo',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SourceTile(
              icon: Icons.close_rounded,
              label: 'Cancel',
              danger: true,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

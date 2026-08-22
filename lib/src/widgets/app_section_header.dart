import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Small uppercase label used to introduce a section of a screen, with an
/// optional trailing text action (e.g. "Refresh", "View All").
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionLoading = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.toUpperCase(), style: AppTextStyles.sectionLabel),
        if (actionLabel != null)
          actionLoading
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../models/order_draft.dart';
import '../localization/app_localizations.dart';

class OrderDraftSummary extends StatelessWidget {
  final OrderDraft draft;

  const OrderDraftSummary({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized.translate('order_draft_title'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(draft.transcript),
          const SizedBox(height: 8),
          Text(localized.translate('order_draft_items')),
          const SizedBox(height: 4),
          ...draft.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item'),
              )),
        ],
      ),
    );
  }
}

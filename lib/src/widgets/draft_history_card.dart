import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/order_draft.dart';
import '../services/local_storage_service.dart';

class DraftHistoryCard extends StatefulWidget {
  const DraftHistoryCard({super.key});

  @override
  State<DraftHistoryCard> createState() => _DraftHistoryCardState();
}

class _DraftHistoryCardState extends State<DraftHistoryCard> {
  List<OrderDraft> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final drafts = await LocalStorageService.getSavedOrderDrafts();
    if (!mounted) return;
    setState(() {
      _drafts = drafts.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localized.translate('draft_history_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Text('Loading...')
            else if (_drafts.isEmpty)
              Text(localized.translate('draft_history_empty'))
            else
              ..._drafts.take(3).map((draft) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.transcript.isEmpty ? localized.translate('draft_history_empty') : draft.transcript,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(draft.items.join(', ')),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

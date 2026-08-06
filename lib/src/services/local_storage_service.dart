import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_draft.dart';
import '../models/order_status.dart';

class LocalStorageService {
  static const _languageKey = 'selected_language';
  static const _savedOrderDraftsKey = 'saved_order_drafts';

  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String?> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  static Future<void> saveOrderDrafts(List<OrderDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = drafts.map((draft) => jsonEncode(draft.toJson())).toList();
    await prefs.setStringList(_savedOrderDraftsKey, payload);
  }

  static Future<void> updateOrderDraftStatus(OrderDraft draftToUpdate, OrderStatus status) async {
    final drafts = await getSavedOrderDrafts();
    final updatedDrafts = drafts.map((draft) {
      final matches = draft.transcript == draftToUpdate.transcript &&
          draft.items.length == draftToUpdate.items.length &&
          draft.items.asMap().entries.every((entry) => entry.value == draftToUpdate.items[entry.key]);

      if (!matches) {
        return draft;
      }

      return OrderDraft(
        transcript: draft.transcript,
        items: draft.items,
        status: status,
      );
    }).toList();

    await saveOrderDrafts(updatedDrafts);
  }

  static Future<List<OrderDraft>> getSavedOrderDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDrafts = prefs.getStringList(_savedOrderDraftsKey) ?? <String>[];
    return rawDrafts
        .map((draft) => OrderDraft.fromJson(jsonDecode(draft) as Map<String, dynamic>))
        .toList();
  }
}

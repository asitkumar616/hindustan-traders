import '../models/voice_product_draft.dart';
import 'voice_transcript_utils.dart';

// Best-effort parser for a spoken "add product" sentence, e.g.
// "add product Rice, unit kg, price 80 rupees". Field order and connector
// words ("is", "as") are flexible, but this is heuristic, not a real NLU
// model -- the caller is expected to let the owner review/edit the filled
// form before saving.
class VoiceProductParser {
  static const _nameLabels = ['product name', 'item name', 'name is', 'product', 'item', 'name'];
  static const _unitLabels = ['unit is', 'unit'];
  static final _stopWords = RegExp(
    r'\b(unit|price|rupees|rupee|rs|product|item|name)\b',
    caseSensitive: false,
  );
  static final _priceKeyword = RegExp(r'\b(price|rupees|rupee|rs)\b', caseSensitive: false);
  static final _number = RegExp(r'\d+(\.\d+)?');

  static VoiceProductDraft parse(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const VoiceProductDraft();
    }

    return VoiceProductDraft(
      name: VoiceTranscriptUtils.extractLabeled(text, _nameLabels, _stopWords),
      unit: VoiceTranscriptUtils.extractLabeled(text, _unitLabels, _stopWords),
      price: _extractPrice(text),
    );
  }

  static double? _extractPrice(String text) {
    final keyword = _priceKeyword.firstMatch(text);
    if (keyword != null) {
      final afterMatch = _number.firstMatch(text.substring(keyword.end));
      if (afterMatch != null) {
        return double.tryParse(afterMatch.group(0)!);
      }
    }

    final anyMatch = _number.firstMatch(text);
    return anyMatch != null ? double.tryParse(anyMatch.group(0)!) : null;
  }
}

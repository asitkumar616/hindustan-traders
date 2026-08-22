import '../models/voice_customer_draft.dart';
import 'auth_service.dart';
import 'voice_transcript_utils.dart';

// Best-effort parser for a spoken/typed "add customer" command. Two shapes
// are supported:
//   - Explicitly labeled: "customer name Raju Stores, mobile 9876543210"
//   - Unlabeled (the common phrasing): "Add Raju Stores mobile 9876543210"
// Heuristic, not a real NLU model -- the caller is expected to let the owner
// review/edit the filled form before saving.
class VoiceCustomerParser {
  static const _nameLabels = ['customer name', 'shop name', 'name is', 'customer', 'shop'];
  static final _stopWords = RegExp(r'\b(mobile|phone|number|contact|customer|shop|address)\b', caseSensitive: false);
  static final _leadingCommand = RegExp(r'^\s*(add|create|new)\s+(a\s+)?(customer|shop)?\s*', caseSensitive: false);
  static final _cutKeyword = RegExp(r'\b(mobile|phone|number|contact)\b', caseSensitive: false);
  static final _longDigitRun = RegExp(r'\d{5,}');

  static VoiceCustomerDraft parse(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const VoiceCustomerDraft();
    }

    return VoiceCustomerDraft(
      name: _extractName(text),
      phone: _extractPhone(text),
    );
  }

  static String? _extractName(String text) {
    final labeled = VoiceTranscriptUtils.extractLabeled(text, _nameLabels, _stopWords);
    if (labeled != null) return _titleCase(labeled);

    var rest = text.replaceFirst(_leadingCommand, '');
    final cutMatch = _cutKeyword.firstMatch(rest);
    if (cutMatch != null) {
      rest = rest.substring(0, cutMatch.start);
    } else {
      final digitsMatch = _longDigitRun.firstMatch(rest);
      if (digitsMatch != null) {
        rest = rest.substring(0, digitsMatch.start);
      }
    }
    rest = rest.replaceAll(RegExp(r'[,.;]+$'), '').trim();
    return rest.isEmpty ? null : _titleCase(rest);
  }

  static String? _extractPhone(String text) {
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    final candidate = digits.length > 12 ? digits.substring(digits.length - 10) : digits;
    return AuthService.normalizeIndianPhone(candidate);
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

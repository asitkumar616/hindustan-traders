// Shared helpers for turning a spoken sentence into labeled field values.
// Heuristic, not a real NLU model -- callers should let the user review the
// filled fields before submitting.
class VoiceTranscriptUtils {
  static String? extractLabeled(String text, List<String> labels, RegExp stopWords) {
    final lower = text.toLowerCase();

    for (final label in labels) {
      final index = lower.indexOf(label);
      if (index == -1) continue;

      var start = index + label.length;
      final rest = text.substring(start);
      final connector = RegExp(r'^\s*(?:is|as|:)?\s*').firstMatch(rest);
      if (connector != null) {
        start += connector.end;
      }

      final tail = text.substring(start);
      final stopMatch = stopWords.firstMatch(tail);
      var value = stopMatch != null ? tail.substring(0, stopMatch.start) : tail;

      value = value.replaceAll(RegExp(r'\d'), '');
      value = value.replaceAll(RegExp(r'[,.;]+$'), '');
      value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }
}

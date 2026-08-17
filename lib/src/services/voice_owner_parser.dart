import '../models/voice_owner_draft.dart';
import 'auth_service.dart';
import 'voice_transcript_utils.dart';

// Best-effort parser for a spoken "add owner" sentence, e.g.
// "add owner Ramesh, mobile number 9876543210, business name Ramesh
// Traders, status approved". Field order and connector words ("is", "as")
// are flexible, but this is heuristic, not a real NLU model -- the caller
// is expected to let the admin review/edit the filled form before saving.
class VoiceOwnerParser {
  static const _businessLabels = ['business name', 'business is', 'shop name', 'business', 'shop'];
  static const _ownerLabels = ['owner name', 'owner is', 'owner named', 'name is', 'owner'];
  static final _stopWords = RegExp(
    r'\b(mobile|phone|number|business|shop|owner|status|approved|approve|rejected|reject|pending)\b',
    caseSensitive: false,
  );

  static VoiceOwnerDraft parse(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const VoiceOwnerDraft();
    }

    return VoiceOwnerDraft(
      ownerName: VoiceTranscriptUtils.extractLabeled(text, _ownerLabels, _stopWords),
      phone: _extractPhone(text),
      businessName: VoiceTranscriptUtils.extractLabeled(text, _businessLabels, _stopWords),
      status: _extractStatus(text.toLowerCase()),
    );
  }

  static String? _extractPhone(String text) {
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    final candidate = digits.length > 12 ? digits.substring(digits.length - 10) : digits;
    return AuthService.normalizeIndianPhone(candidate);
  }

  static String? _extractStatus(String lower) {
    if (lower.contains('approve')) return 'approved';
    if (lower.contains('reject')) return 'rejected';
    if (lower.contains('pending')) return 'pending';
    return null;
  }
}

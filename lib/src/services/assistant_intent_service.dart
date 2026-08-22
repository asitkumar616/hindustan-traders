import '../models/voice_customer_draft.dart';
import '../models/voice_product_draft.dart';
import 'voice_customer_parser.dart';
import 'voice_product_parser.dart';

enum AssistantIntentType {
  addCustomer,
  addProduct,
  showTodaysSales,
  showCustomers,
  showProducts,
  unknown,
}

class AssistantIntent {
  const AssistantIntent({required this.type, this.customerDraft, this.productDraft});

  final AssistantIntentType type;
  final VoiceCustomerDraft? customerDraft;
  final VoiceProductDraft? productDraft;
}

/// The single command-processing layer the universal assistant runs every
/// request through, whether it arrived as typed text or as speech-to-text
/// output -- there is deliberately no separate logic path for voice.
///
/// Phase 1: pure local keyword/pattern heuristics, no external AI API.
/// Reuses the existing VoiceProductParser/VoiceCustomerParser field
/// extractors so there is exactly one implementation of "how to read a
/// product/customer out of a sentence", shared with the in-dialog
/// "Speak to fill" buttons.
class AssistantIntentService {
  static final RegExp _addVerb = RegExp(r'\b(add|create|new)\b', caseSensitive: false);
  static final RegExp _showVerb = RegExp(r'\b(show|view|open|list|display)\b', caseSensitive: false);
  static final RegExp _tenDigitPhone = RegExp(r'[6-9]\d{9}');
  static final RegExp _priceOrUnitCue = RegExp(
    r'\b(rupee|rupees|rs|kg|kgs|gram|grams|litre|litres|liter|liters|dozen|price|per|bag|bags|box|boxes|pack|packet|packets)\b',
    caseSensitive: false,
  );
  static final RegExp _salesWords = RegExp(r'\b(sale|sales|revenue|earning|earnings)\b', caseSensitive: false);

  static AssistantIntent detect(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return const AssistantIntent(type: AssistantIntentType.unknown);
    }

    final lower = text.toLowerCase();
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    final hasPhoneNumber = _tenDigitPhone.hasMatch(digitsOnly);
    final hasAddVerb = _addVerb.hasMatch(lower);
    final hasShowVerb = _showVerb.hasMatch(lower);
    final hasPriceOrUnitCue = _priceOrUnitCue.hasMatch(lower);

    if (hasAddVerb && hasPhoneNumber && !hasPriceOrUnitCue) {
      return AssistantIntent(type: AssistantIntentType.addCustomer, customerDraft: VoiceCustomerParser.parse(text));
    }
    if (hasAddVerb && (lower.contains('product') || hasPriceOrUnitCue)) {
      return AssistantIntent(type: AssistantIntentType.addProduct, productDraft: VoiceProductParser.parse(text));
    }
    if (hasAddVerb && (lower.contains('customer') || lower.contains('shop'))) {
      return AssistantIntent(type: AssistantIntentType.addCustomer, customerDraft: VoiceCustomerParser.parse(text));
    }
    if (hasShowVerb && _salesWords.hasMatch(lower)) {
      return const AssistantIntent(type: AssistantIntentType.showTodaysSales);
    }
    if (hasShowVerb && lower.contains('customer')) {
      return const AssistantIntent(type: AssistantIntentType.showCustomers);
    }
    if (hasShowVerb && lower.contains('product')) {
      return const AssistantIntent(type: AssistantIntentType.showProducts);
    }

    return const AssistantIntent(type: AssistantIntentType.unknown);
  }
}

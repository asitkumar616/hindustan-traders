import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../screens/owner_customer_management_screen.dart';
import '../screens/owner_product_management_screen.dart';
import '../screens/owner_transactions_screen.dart';
import '../services/assistant_intent_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_sound_level_meter.dart';

const List<String> _kAssistantSuggestions = [
  'Show today\'s sales',
  'Show customers',
  'Show products',
  'Add a customer',
  'Add a product',
];

/// The universal voice/text assistant. Every request -- typed or spoken --
/// runs through the same [AssistantIntentService.detect] call and is then
/// routed to an existing screen/form; there is no separate business logic
/// for voice vs. text, and no write action (add customer/product) ever
/// saves without the owner reviewing the pre-filled form first.
class AskAssistantSheet extends StatefulWidget {
  const AskAssistantSheet({super.key, required this.businessId});

  final String businessId;

  @override
  State<AskAssistantSheet> createState() => _AskAssistantSheetState();
}

class _AskAssistantSheetState extends State<AskAssistantSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();

  bool _isListening = false;
  String _liveTranscript = '';
  String? _feedback;
  double _soundLevel = 0;

  @override
  void initState() {
    super.initState();
    _speech.initialize(onError: _handleError, onStatus: _handleStatus);
  }

  @override
  void dispose() {
    if (_speech.isListening) {
      _speech.stop();
    }
    _textController.dispose();
    super.dispose();
  }

  void _handleStatus(String status) {
    if (!mounted) return;
    if (status == stt.SpeechToText.doneStatus || status == stt.SpeechToText.notListeningStatus) {
      if (_isListening) {
        setState(() => _isListening = false);
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _feedback = _friendlyErrorMessage(error.errorMsg);
    });
  }

  String _friendlyErrorMessage(String errorMsg) {
    switch (errorMsg) {
      case 'error_permission':
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Microphone permission is required to speak your request.';
      case 'error_no_match':
      case 'error_speech_timeout':
      case 'no-speech':
        return "Didn't catch that -- try again, or type your request below.";
      case 'error_network':
      case 'error_network_timeout':
      case 'network':
        return 'No internet connection. Voice recognition needs data/Wi-Fi.';
      default:
        return 'Something went wrong while listening. Please try again or type instead.';
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final permission = await Permission.microphone.request();
    if (!mounted) return;
    if (permission.isDenied || permission.isPermanentlyDenied) {
      setState(() => _feedback = 'Microphone permission is required to speak your request.');
      return;
    }
    if (!_speech.isAvailable) {
      setState(() => _feedback = 'Speech recognition is unavailable on this device. Please type your request instead.');
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _feedback = null;
      _soundLevel = 0;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _liveTranscript = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _textController.text = result.recognizedWords;
          _handleCommand(result.recognizedWords);
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  void _handleCommand(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;

    final intent = AssistantIntentService.detect(text);

    switch (intent.type) {
      case AssistantIntentType.addCustomer:
        _openScreen(OwnerCustomerManagementScreen(
          businessId: widget.businessId,
          autoOpenAdd: true,
          initialName: intent.customerDraft?.name,
          initialPhone: intent.customerDraft?.phone,
        ));
      case AssistantIntentType.addProduct:
        _openScreen(OwnerProductManagementScreen(
          businessId: widget.businessId,
          autoOpenAdd: true,
          initialDraft: intent.productDraft,
        ));
      case AssistantIntentType.showTodaysSales:
        _openScreen(OwnerTransactionsScreen(businessId: widget.businessId, todayOnly: true));
      case AssistantIntentType.showCustomers:
        _openScreen(OwnerCustomerManagementScreen(businessId: widget.businessId));
      case AssistantIntentType.showProducts:
        _openScreen(OwnerProductManagementScreen(businessId: widget.businessId));
      case AssistantIntentType.unknown:
        setState(() {
          _feedback = "Sorry, I didn't understand that. Try one of the examples above, or use the app's normal buttons.";
        });
    }
  }

  void _openScreen(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Ask Assistant', style: AppTextStyles.heading)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ownerPrimary.withValues(alpha: _isListening ? 0.16 : 0.1),
                      border: Border.all(color: AppColors.ownerPrimary.withValues(alpha: _isListening ? 0.5 : 0.25), width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ownerPrimary),
                        child: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _isListening ? 'Listening...' : 'What can I help you with?',
                textAlign: TextAlign.center,
                style: AppTextStyles.subheading,
              ),
              if (_isListening) ...[
                const SizedBox(height: AppSpacing.sm),
                AppSoundLevelMeter(level: _soundLevel, activeColor: AppColors.ownerPrimary),
              ],
              if (_liveTranscript.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('"$_liveTranscript"', textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1DC), borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_feedback!, style: const TextStyle(color: Color(0xFFC9820A))),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: _kAssistantSuggestions
                    .map((suggestion) => ActionChip(
                          label: Text(suggestion),
                          onPressed: () => _handleCommand(suggestion),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: TextField(
                  controller: _textController,
                  onSubmitted: _handleCommand,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Type your request...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.ownerPrimary),
                      onPressed: () => _handleCommand(_textController.text),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

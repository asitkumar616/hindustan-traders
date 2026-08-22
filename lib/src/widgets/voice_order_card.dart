import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../localization/app_localizations.dart';
import '../models/order_draft.dart';
import '../services/order_draft_service.dart';
import 'app_sound_level_meter.dart';
import 'order_draft_summary.dart';

class VoiceOrderCard extends StatefulWidget {
  const VoiceOrderCard({super.key, this.businessId});

  // The shop this order should be placed against. Omit to fall back to the
  // caller's default business (used by the owner's own voice-order card).
  final String? businessId;

  @override
  State<VoiceOrderCard> createState() => _VoiceOrderCardState();
}

class _VoiceOrderCardState extends State<VoiceOrderCard> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isRecording = false;
  bool _isSubmitting = false;
  String _liveTranscript = '';
  String _status = '';
  double _soundLevel = 0;

  // The running cart for this shop. Each recognized utterance adds items
  // to this list rather than replacing it -- this is what lets the
  // customer build a multi-item order ("give me 5kg rice", then later
  // "also toor dal") before confirming, instead of every mic tap
  // discarding whatever was already recognized.
  final List<String> _cartItems = [];
  final List<String> _transcriptLog = [];

  bool get _hasCartItems => _cartItems.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: _handleSpeechError,
      onStatus: _handleSpeechStatus,
    );
    if (!available && mounted) {
      setState(() {
        _status = AppLocalizations.of(context).translate('voice_order_speech_unavailable');
      });
    }
  }

  // speech_to_text stops listening (e.g. after the pause/listen timeouts
  // elapse, or when the platform recognizer finishes) without necessarily
  // ever delivering a final onResult. Without this, `_isRecording` could
  // stay true forever and the mic button would look stuck on "Recording..."
  // even though nothing is being captured any more.
  void _handleSpeechStatus(String status) {
    if (!mounted) return;
    if (status == stt.SpeechToText.doneStatus || status == stt.SpeechToText.notListeningStatus) {
      if (_isRecording) {
        setState(() {
          _isRecording = false;
          if (_liveTranscript.isEmpty) {
            _status = "Didn't catch anything. Tap the mic and try again.";
          }
        });
      }
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _status = _friendlyErrorMessage(error.errorMsg);
    });
  }

  // Android/iOS report `error_*` codes; the web implementation forwards the
  // browser's raw Web Speech API codes (`not-allowed`, `no-speech`, ...)
  // unprefixed. Both are handled here since this widget runs on both.
  String _friendlyErrorMessage(String errorMsg) {
    switch (errorMsg) {
      case 'error_permission':
      case 'not-allowed':
      case 'service-not-allowed':
        return AppLocalizations.of(context).translate('voice_order_permission_denied');
      case 'error_no_match':
      case 'error_speech_timeout':
      case 'no-speech':
        return "Didn't catch anything. Tap the mic and try again.";
      case 'error_network':
      case 'error_network_timeout':
      case 'network':
        return 'No internet connection. Voice recognition needs data/Wi-Fi.';
      case 'error_audio_error':
      case 'audio-capture':
        return 'Microphone error. Check that a mic is connected and not in use by another app.';
      case 'error_busy':
        return 'Voice recognition is busy. Please try again in a moment.';
      case 'not supported':
      case 'speech_not_supported':
        return 'Voice recognition is not supported on this browser/device. Try Chrome or a supported mobile device.';
      default:
        return 'Something went wrong while listening. Please try again.';
    }
  }

  Future<void> _toggleRecording(BuildContext context) async {
    final localized = AppLocalizations.of(context);
    final permission = await Permission.microphone.request();

    if (!mounted) return;

    if (permission.isDenied || permission.isPermanentlyDenied) {
      setState(() {
        _status = localized.translate('voice_order_permission_denied');
      });
      return;
    }

    if (!_speech.isAvailable) {
      setState(() {
        _status = localized.translate('voice_order_speech_unavailable');
      });
      return;
    }

    if (_isRecording) {
      await _speech.stop();
      setState(() {
        _isRecording = false;
        _status = localized.translate('voice_order_stopped');
      });
      return;
    }

    setState(() {
      _isRecording = true;
      _status = localized.translate('voice_order_recording');
      _liveTranscript = '';
      _soundLevel = 0;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _liveTranscript = result.recognizedWords;
          if (result.finalResult) {
            _addUtteranceToCart(result.recognizedWords, localized);
            _isRecording = false;
          }
        });
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
    );
  }

  void _addUtteranceToCart(String transcript, AppLocalizations localized) {
    final parsed = OrderDraftService.parseTranscript(transcript);
    final newItems = parsed.items.where((item) => item != 'No items detected').toList();

    if (newItems.isEmpty) {
      _status = localized.translate('voice_order_stopped');
      return;
    }

    _transcriptLog.add(transcript);
    for (final item in newItems) {
      if (!_cartItems.contains(item)) {
        _cartItems.add(item);
      }
    }
    _status = 'Added to cart. Tap the mic again to add more, or confirm to place the order.';
  }

  OrderDraft get _cartDraft => OrderDraft(transcript: _transcriptLog.join(' | '), items: _cartItems);

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _transcriptLog.clear();
      _liveTranscript = '';
      _status = 'Cart cleared.';
    });
  }

  Future<void> _submitDraft() async {
    if (!_hasCartItems) {
      setState(() {
        _status = AppLocalizations.of(context).translate('voice_order_submit_empty');
      });
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await OrderDraftService.submitDraft(_cartDraft, businessId: widget.businessId);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _status = result.message.isNotEmpty
          ? result.message
          : (result.success
              ? AppLocalizations.of(context).translate('voice_order_submitted')
              : AppLocalizations.of(context).translate('voice_order_submit_saved_locally'));

      if (result.success) {
        // Order placed -- start a fresh cart for whatever comes next.
        _cartItems.clear();
        _transcriptLog.clear();
        _liveTranscript = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localized.translate('voice_order_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(localized.translate('voice_order_message')),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _toggleRecording(context),
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(
                _isRecording
                    ? localized.translate('voice_order_stop_button')
                    : (_hasCartItems ? 'Add more items' : localized.translate('voice_order_button')),
              ),
            ),
            if (_isRecording) ...[
              const SizedBox(height: 12),
              AppSoundLevelMeter(level: _soundLevel, activeColor: Colors.green.shade500),
            ],
            const SizedBox(height: 12),
            if (_status.isNotEmpty)
              Text(
                _status,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (_liveTranscript.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localized.translate('voice_order_preview_title')),
                    const SizedBox(height: 6),
                    Text(_liveTranscript),
                  ],
                ),
              ),
            ],
            if (_hasCartItems) ...[
              const SizedBox(height: 8),
              OrderDraftSummary(draft: _cartDraft),
            ],
            const SizedBox(height: 12),
            if (_hasCartItems) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _submitDraft,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(localized.translate('voice_order_submit_button')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isSubmitting ? null : _clearCart,
                    child: const Text('Clear cart'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              localized.translate('voice_order_hint'),
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}


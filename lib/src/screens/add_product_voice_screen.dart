import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/voice_product_parser.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_sound_level_meter.dart';
import 'voice_product_result_screen.dart';

class AddProductVoiceScreen extends StatefulWidget {
  const AddProductVoiceScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<AddProductVoiceScreen> createState() => _AddProductVoiceScreenState();
}

class _AddProductVoiceScreenState extends State<AddProductVoiceScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _liveTranscript = '';
  String _status = 'Tap the mic to start';
  double _soundLevel = 0;

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
    final available = await _speech.initialize(onError: _handleError, onStatus: _handleStatus);
    if (!available && mounted) {
      setState(() => _status = 'Speech recognition is unavailable on this device.');
    }
  }

  void _handleStatus(String status) {
    if (!mounted) return;
    if (status == stt.SpeechToText.doneStatus || status == stt.SpeechToText.notListeningStatus) {
      if (_isListening) {
        setState(() {
          _isListening = false;
          if (_liveTranscript.isEmpty) {
            _status = "Didn't catch anything. Tap the mic and try again.";
          }
        });
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _status = _friendlyErrorMessage(error.errorMsg);
    });
  }

  String _friendlyErrorMessage(String errorMsg) {
    switch (errorMsg) {
      case 'error_permission':
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Microphone permission is required to continue.';
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
      default:
        return 'Something went wrong while listening. Please try again.';
    }
  }

  Future<void> _toggleListening() async {
    final permission = await Permission.microphone.request();
    if (!mounted) return;

    if (permission.isDenied || permission.isPermanentlyDenied) {
      setState(() => _status = 'Microphone permission is required to continue.');
      return;
    }

    if (!_speech.isAvailable) {
      setState(() => _status = 'Speech recognition is unavailable on this device.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _status = 'Listening...';
      _soundLevel = 0;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _liveTranscript = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _handleFinalTranscript(result.recognizedWords);
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
    );
  }

  void _handleFinalTranscript(String transcript) {
    final draft = VoiceProductParser.parse(transcript);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceProductResultScreen(businessId: widget.businessId, draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xl, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                  const Expanded(child: Text('Add Product (Voice)', style: AppTextStyles.heading, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ownerPrimary.withValues(alpha: _isListening ? 0.16 : 0.1),
                  border: Border.all(
                    color: AppColors.ownerPrimary.withValues(alpha: _isListening ? 0.5 : 0.25),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ownerPrimary),
                    child: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(_status, style: AppTextStyles.subheading, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            const Text('Speak to add product', style: AppTextStyles.bodyMuted),
            if (_isListening) ...[
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: AppSoundLevelMeter(level: _soundLevel, activeColor: AppColors.ownerPrimary),
              ),
            ],
            if (_liveTranscript.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  '"$_liveTranscript"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                ),
              ),
            ],
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: Text(
                'Example: "Add Kohinoor rice 25 kg bag at 60 rupees per kg"',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

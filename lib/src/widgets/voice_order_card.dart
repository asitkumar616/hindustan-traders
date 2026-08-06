import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../localization/app_localizations.dart';
import '../models/order_draft.dart';
import '../services/order_draft_service.dart';
import 'order_draft_summary.dart';

class VoiceOrderCard extends StatefulWidget {
  const VoiceOrderCard({super.key});

  @override
  State<VoiceOrderCard> createState() => _VoiceOrderCardState();
}

class _VoiceOrderCardState extends State<VoiceOrderCard> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isRecording = false;
  String _transcript = '';
  String _status = '';
  OrderDraft? _draft;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (!available && mounted) {
      setState(() {
        _status = AppLocalizations.of(context).translate('voice_order_speech_unavailable');
      });
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
      _transcript = '';
      _draft = null;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _transcript = result.recognizedWords;
          if (result.finalResult) {
            _draft = _buildDraft(_transcript);
            _status = localized.translate('voice_order_stopped');
            _isRecording = false;
          }
        });
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  OrderDraft _buildDraft(String transcript) {
    return OrderDraftService.parseTranscript(transcript);
  }

  Future<void> _submitDraft() async {
    if (_draft == null) {
      setState(() {
        _status = AppLocalizations.of(context).translate('voice_order_submit_empty');
      });
      return;
    }

    final result = await OrderDraftService.submitDraft(_draft!);
    if (!mounted) return;

    setState(() {
      _status = result.message.isNotEmpty ? result.message : (result.success
          ? AppLocalizations.of(context).translate('voice_order_submitted')
          : AppLocalizations.of(context).translate('voice_order_submit_saved_locally'));
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
              onPressed: () => _toggleRecording(context),
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(
                _isRecording
                    ? localized.translate('voice_order_stop_button')
                    : localized.translate('voice_order_button'),
              ),
            ),
            const SizedBox(height: 12),
            if (_status.isNotEmpty)
              Text(
                _status,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (_transcript.isNotEmpty) ...[
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
                    Text(_transcript),
                  ],
                ),
              ),
            ],
            if (_draft != null) ...[
              const SizedBox(height: 8),
              OrderDraftSummary(draft: _draft!),
            ],
            const SizedBox(height: 12),
            if (_transcript.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitDraft,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(localized.translate('voice_order_submit_button')),
                ),
              ),
            const SizedBox(height: 8),
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

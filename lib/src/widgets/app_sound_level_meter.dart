import 'package:flutter/material.dart';

/// Live bar-meter driven by [SpeechToText]'s `onSoundLevelChange`, so the
/// user gets visible proof the microphone is actually picking up audio
/// while "Listening..."/"Recording..." is shown -- rather than just
/// trusting a status label. Shared by every voice-input screen.
class AppSoundLevelMeter extends StatelessWidget {
  const AppSoundLevelMeter({super.key, required this.level, this.activeColor = Colors.green});

  final double level;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    // Reported levels vary by platform but roughly span this range; clamp
    // and normalize to 0-1 so the bars scale consistently everywhere.
    final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
    const barCount = 12;
    final activeBars = (normalized * barCount).round();

    return Row(
      children: List.generate(barCount, (index) {
        final active = index < activeBars;
        return Expanded(
          child: Container(
            height: 6 + (index % 3) * 4,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/widgets/timer_duration_text.dart';

class PracticeTimerCard extends StatelessWidget {
  const PracticeTimerCard({
    super.key,
    required this.timer,
    required this.onTap,
  });

  final PresetTimer timer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TimerDurationText(
                durationMs: timer.durationMs,
                valueFontSize: 28,
                compactValueFontSize: 18,
                unitFontSize: 14,
                color: textColor,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

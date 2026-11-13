import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';

/// Mixed-size duration label matching the timer list: `1 min`, `1hr 24min`,
/// `1hr 24min 23sec`. Leftover-second numbers match the unit size.
class TimerDurationText extends StatelessWidget {
  const TimerDurationText({
    super.key,
    required this.durationMs,
    this.valueFontSize = 40,
    this.compactValueFontSize = 22,
    this.unitFontSize = 22,
    this.fontWeight = FontWeight.w300,
    this.color,
    this.maxLines,
    this.overflow,
  });

  final int durationMs;
  final double valueFontSize;
  final double compactValueFontSize;
  final double unitFontSize;
  final FontWeight fontWeight;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final isTibetan = AppFontConfig.isTibetanLanguage(
      Localizations.localeOf(context).languageCode,
    );
    final textColor = color ?? Theme.of(context).colorScheme.onSurface;
    final parts = PresetTimer.durationPartsFromMs(durationMs);
    final compound = parts.length > 1;
    final l10n = context.l10n;

    TextStyle valueStyle(bool compact) => TextStyle(
      fontSize: compact ? compactValueFontSize : valueFontSize,
      fontWeight: fontWeight,
      height: isTibetan ? AppFontConfig.tibetanCompactLineHeight : 1,
      leadingDistribution:
          isTibetan ? AppFontConfig.tibetanLeadingDistribution : null,
      color: textColor,
    );
    final unitStyle = TextStyle(
      fontSize: unitFontSize,
      fontWeight: fontWeight,
      height: isTibetan ? AppFontConfig.tibetanCompactLineHeight : 28 / 22,
      leadingDistribution:
          isTibetan ? AppFontConfig.tibetanLeadingDistribution : null,
      color: textColor,
    );

    String unitFor(TimerDurationPart part) => switch (part.unit) {
      TimerDurationUnit.hours => l10n.timer_duration_hr,
      TimerDurationUnit.minutes => l10n.timer_min,
      TimerDurationUnit.seconds => l10n.timer_duration_sec,
    };

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) const TextSpan(text: ' '),
            ..._spansForPart(
              part: parts[i],
              unit: unitFor(parts[i]),
              isTibetan: isTibetan,
              compound: compound,
              valueStyle: valueStyle(parts[i].compact),
              unitStyle: unitStyle,
            ),
          ],
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan> _spansForPart({
    required TimerDurationPart part,
    required String unit,
    required bool isTibetan,
    required bool compound,
    required TextStyle valueStyle,
    required TextStyle unitStyle,
  }) {
    final value = TextSpan(text: '${part.value}', style: valueStyle);
    final unitSpan = TextSpan(text: unit, style: unitStyle);
    // A real space (not a spacer widget) so screen readers and text finders
    // read "1 min", not "1\uFFFCmin".
    final gap = compound ? null : TextSpan(text: ' ', style: unitStyle);
    if (isTibetan) {
      return gap == null ? [unitSpan, value] : [unitSpan, gap, value];
    }
    return gap == null ? [value, unitSpan] : [value, gap, unitSpan];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/widgets/preset_timer_card.dart';
import 'package:flutter_pecha/features/timer/presentation/widgets/timer_duration_text.dart';

/// One tappable timer in the "Add to session" picker: the duration with its
/// ambient sound underneath and, for a timer the user created, its title on
/// the right. The whole card is the tap target; there is no play or ⋮ button.
class TimerPickerCard extends StatelessWidget {
  const TimerPickerCard({
    super.key,
    required this.timer,
    this.soundLabel,
    this.onTap,
  });

  final PresetTimer timer;

  /// Ambient sound name, or the "no sound" label. Null while a sound id is
  /// set but its name has not loaded yet.
  final String? soundLabel;
  final VoidCallback? onTap;

  static const double _borderRadius = 16;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = textColor.withValues(alpha: 0.55);
    final isTibetan = AppFontConfig.isTibetanLanguage(
      Localizations.localeOf(context).languageCode,
    );
    final leading = isTibetan ? AppFontConfig.tibetanLeadingDistribution : null;

    final duration = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TimerDurationText(
          durationMs: timer.durationMs,
          valueFontSize: 34,
          compactValueFontSize: 20,
          unitFontSize: 20,
          color: textColor,
        ),
        if (soundLabel != null) ...[
          const SizedBox(height: 6),
          TimerSoundLabel(label: soundLabel!, color: mutedColor),
        ],
      ],
    );

    final title = timer.isUserCreated ? timer.description?.trim() : null;

    return Material(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(_borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child:
              title == null || title.isEmpty
                  ? Align(alignment: Alignment.centerLeft, child: duration)
                  : Row(
                    children: [
                      Expanded(child: duration),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height:
                                isTibetan
                                    ? AppFontConfig.tibetanCompactLineHeight
                                    : null,
                            leadingDistribution: leading,
                            color: textColor,
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

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/widgets/timer_duration_text.dart';

/// One timer in the presets / your-timers list: duration, sound, and actions.
///
/// Every row has a ⋮ menu and a play button. Preset rows sit inside one
/// grouped card; user-created rows are standalone cards.
class PresetTimerCard extends StatelessWidget {
  const PresetTimerCard({
    super.key,
    required this.timer,
    this.soundLabel,
    this.onPlay,
    this.onMoreTap,
    this.standalone = false,
  });

  final PresetTimer timer;

  /// Ambient sound name, or the "no sound" label. Null while a sound id is
  /// set but its name has not loaded yet.
  final String? soundLabel;
  final VoidCallback? onPlay;
  final VoidCallback? onMoreTap;

  /// True for "Your timers" cards, which get their own card surface.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = isDark ? AppColors.textTertiaryDark : AppColors.grey800;
    final isTibetan = AppFontConfig.isTibetanLanguage(
      Localizations.localeOf(context).languageCode,
    );
    final customTitle = timer.isUserCreated ? timer.description?.trim() : null;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (customTitle != null && customTitle.isNotEmpty) ...[
          Text(
            customTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: isTibetan ? AppFontConfig.tibetanCompactLineHeight : null,
              leadingDistribution:
                  isTibetan ? AppFontConfig.tibetanLeadingDistribution : null,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
        ],
        TimerDurationText(durationMs: timer.durationMs, color: textColor),
        if (soundLabel != null) ...[
          const SizedBox(height: 2),
          TimerSoundLabel(label: soundLabel!, color: mutedColor),
        ],
      ],
    );

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: standalone ? 16 : 0,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: standalone ? info : InkWell(onTap: onPlay, child: info),
          ),
          if (onMoreTap != null)
            SizedBox(
              width: 24,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.expand(),
                icon: Icon(
                  AppAssets.dotsThreeVertical,
                  color: textColor,
                  size: 24,
                ),
                onPressed: onMoreTap,
              ),
            ),
          const SizedBox(width: 16),
          _PlayButton(isDark: isDark, onPressed: onPlay),
        ],
      ),
    );

    if (!standalone) return row;

    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceWhite;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onPlay, child: row),
    );
  }
}

/// Waveform icon and ambient sound name under a timer's duration.
class TimerSoundLabel extends StatelessWidget {
  const TimerSoundLabel({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(AppAssets.timerAmbientSound, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isDark, this.onPressed});

  final bool isDark;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.grey500 : AppColors.grey800;

    return Material(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceWhite,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Icon(AppAssets.play, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

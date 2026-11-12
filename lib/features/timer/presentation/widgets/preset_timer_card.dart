import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/widgets/timer_duration_text.dart';

/// One timer in the presets / your-timers list: duration, sound, and actions.
///
/// Preset rows sit inside a grouped card with a ⋮ icon and a play button.
/// User-created rows are standalone cards with a circled ⋮; tapping the
/// card starts the session.
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

  /// True for "Your timers" cards: own white surface, circled ⋮, no play.
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
          _SoundLabel(label: soundLabel!, color: mutedColor),
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
          if (standalone)
            _CircleIconButton(
              isDark: isDark,
              icon: AppAssets.dotsThreeVertical,
              onPressed: onMoreTap,
            )
          else ...[
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

class _SoundLabel extends StatelessWidget {
  const _SoundLabel({required this.label, required this.color});

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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.isDark,
    required this.icon,
    this.onPressed,
  });

  final bool isDark;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.grey300;
    final fill = isDark ? AppColors.surfaceDark : AppColors.surfaceWhite;

    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 24, color: iconColor),
      ),
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

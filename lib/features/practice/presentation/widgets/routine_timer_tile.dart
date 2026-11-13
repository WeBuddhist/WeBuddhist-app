import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_pecha/features/timer/presentation/providers/timers_providers.dart';
import 'package:flutter_pecha/features/timer/presentation/widgets/preset_timer_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pecha/features/timer/presentation/widgets/timer_duration_text.dart';

/// A timer inside a practice block, in the same style as the timer cards:
/// the custom title, the duration in large type and the ambient sound.
///
/// Sits in the same card as the block's other items so rows line up. Older
/// items saved as a bare duration have no linked timer, so they show the
/// duration alone.
class RoutineTimerTile extends ConsumerWidget {
  const RoutineTimerTile({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
  });

  final RoutineItem item;
  final VoidCallback? onTap;

  /// Shown on the right, e.g. the editor's drag handle.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = textColor.withValues(alpha: 0.55);
    final isTibetan = AppFontConfig.isTibetanLanguage(
      Localizations.localeOf(context).languageCode,
    );
    final leading = isTibetan ? AppFontConfig.tibetanLeadingDistribution : null;

    final soundsById = ref.watch(ambientSoundByIdProvider);
    final linked = item.timer?.toEntity();
    final durationMs = item.durationMs ?? linked?.durationMs ?? 0;

    final customTitle =
        linked != null && linked.isUserCreated
            ? linked.description?.trim()
            : null;

    // Null for a bare-duration item, or while the sound catalogue loads.
    String? soundLabel() {
      if (linked == null) return null;
      final soundId = linked.ambientSoundId;
      if (soundId == null || soundId.isEmpty) {
        return l10n.timer_ambient_sound_none;
      }
      return soundsById[soundId]?.name;
    }

    final sound = soundLabel();

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (customTitle != null && customTitle.isNotEmpty) ...[
                        Text(
                          customTitle,
                          maxLines: 1,
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
                        const SizedBox(height: 6),
                      ],
                      TimerDurationText(
                        durationMs: durationMs,
                        valueFontSize: 28,
                        compactValueFontSize: 18,
                        unitFontSize: 18,
                        color: textColor,
                      ),
                      if (sound != null) ...[
                        const SizedBox(height: 6),
                        TimerSoundLabel(label: sound, color: mutedColor),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

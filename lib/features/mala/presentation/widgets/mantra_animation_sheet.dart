import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/tibetan_numerals.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_settings_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_sheet_frame.dart';
import 'package:flutter_pecha/shared/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opened from Mala settings: turns the mantra marquee on or off and picks its
/// speed. Changes apply at once and are saved in [malaSettingsProvider].
class MantraAnimationSheet extends ConsumerWidget {
  const MantraAnimationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => const MantraAnimationSheet(),
    );
  }

  /// "1x", "0.75x": the value shown on the chip and in Mala settings.
  static String speedLabel(BuildContext context, double speed) {
    var text = speed.toStringAsFixed(2);
    while (text.contains('.') && (text.endsWith('0') || text.endsWith('.'))) {
      text = text.substring(0, text.length - 1);
    }
    final label = '${text}x';
    return context.isTibetanLocale ? toTibetanDigits(label) : label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(malaSettingsProvider);
    final notifier = ref.read(malaSettingsProvider.notifier);
    final onSurface = theme.colorScheme.onSurface;
    final dividerColor = isDark ? AppColors.cardBorderDark : AppColors.grey300;
    final play = settings.playAnimation;

    return MalaSheetFrame(
      title: l10n.mala_mantra_animation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mala_play_animation,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AppToggleSwitch(
                  value: play,
                  onChanged: notifier.setPlayAnimation,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: play ? 1 : 0.38,
            child: IgnorePointer(
              ignoring: !play,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      l10n.mala_speed,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final preset in kMalaMantraSpeedPresets)
                          _SpeedChip(
                            label: speedLabel(context, preset),
                            caption:
                                preset == kMalaMantraSpeedDefault
                                    ? l10n.mala_speed_normal
                                    : null,
                            selected:
                                (settings.mantraSpeed - preset).abs() < 0.001,
                            onTap: () => notifier.setMantraSpeed(preset),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
  });

  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final fill =
        selected
            ? (isDark ? AppColors.textPrimaryDark : Colors.black)
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceWhite);
    final foreground =
        selected ? (isDark ? AppColors.textPrimary : Colors.white) : onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: fill,
          shape: StadiumBorder(
            side: BorderSide(
              color:
                  selected
                      ? Colors.transparent
                      : (isDark ? AppColors.cardBorderDark : AppColors.grey300),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 52),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              alignment: Alignment.center,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

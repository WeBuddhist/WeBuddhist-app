import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';

/// End of the reader text when opened from a group accumulation with text
/// content: how many recitations this visit holds, then Recite again, Finish
/// and count, and Finish without counting.
class GroupAccumulatorChantFooter extends StatelessWidget {
  const GroupAccumulatorChantFooter({
    super.key,
    required this.completedCount,
    required this.onReciteAgain,
    required this.onFinishAndCount,
    required this.onFinishWithoutCounting,
    this.canCount = true,
    this.isFinishing = false,
  });

  /// Recitations in this visit, the one just finished included.
  final int completedCount;

  /// Counts the recitation just finished and goes back to the start.
  final VoidCallback onReciteAgain;

  /// Counts the recitation just finished and ends the session.
  final VoidCallback onFinishAndCount;

  /// Ends the session, adding nothing.
  final VoidCallback onFinishWithoutCounting;

  /// False while the selected target cannot take a count yet; the two
  /// counting actions are disabled meanwhile.
  final bool canCount;

  /// True while the session is being finished; every action is disabled so
  /// none can count the same recitation again.
  final bool isFinishing;

  static const _buttonHeight = 52.0;
  static const _borderRadius = 999.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final countEnabled = canCount && !isFinishing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          Text(
            l10n.group_accumulator_completed_recitations,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: secondaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            '$completedCount',
            key: const Key('group_accumulator_completed_count'),
            textAlign: TextAlign.center,
            // Figma: the number is set in the content (serif) font.
            style: TextStyle(
              fontFamily: AppFontConfig.getFontFamily('en', FontType.content),
              fontSize: 64,
              height: 1.1,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),
          _ChantActionButton(
            label: l10n.group_accumulator_recite_again,
            backgroundColor: isDark
                ? AppColors.surfaceWhite
                : AppColors.textPrimary,
            foregroundColor: isDark
                ? AppColors.textPrimary
                : AppColors.surfaceWhite,
            onTap: countEnabled ? onReciteAgain : null,
          ),
          const SizedBox(height: 12),
          _ChantActionButton(
            label: l10n.group_accumulator_finish_and_count,
            backgroundColor: isDark
                ? AppColors.cardBorderDark
                : AppColors.grey100,
            foregroundColor: textColor,
            onTap: countEnabled ? onFinishAndCount : null,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isFinishing ? null : onFinishWithoutCounting,
            style: TextButton.styleFrom(foregroundColor: textColor),
            child: Text(
              l10n.group_accumulator_finish_without_counting,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChantActionButton extends StatelessWidget {
  const _ChantActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor.withValues(alpha: onTap == null ? 0.45 : 1),
      borderRadius: BorderRadius.circular(
        GroupAccumulatorChantFooter._borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: GroupAccumulatorChantFooter._buttonHeight,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

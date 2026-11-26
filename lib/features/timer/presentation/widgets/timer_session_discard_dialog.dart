import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

enum _TimerSessionDiscardAction { discard, save }

/// Mid-session discard confirmation (Figma light mode; dark uses app tokens).
///
/// [onDismissed] runs only when the user taps the scrim or otherwise dismisses
/// without choosing discard or save.
Future<void> showTimerSessionDiscardDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String discardLabel,
  required String saveLabel,
  required VoidCallback onDiscard,
  required VoidCallback onSave,
  VoidCallback? onDismissed,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final action = await showDialog<_TimerSessionDiscardAction>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) {
      return TimerSessionDiscardDialog(
        title: title,
        message: message,
        discardLabel: discardLabel,
        saveLabel: saveLabel,
        isDark: isDark,
        onDiscard: () => Navigator.of(dialogContext).pop(
          _TimerSessionDiscardAction.discard,
        ),
        onSave: () => Navigator.of(dialogContext).pop(
          _TimerSessionDiscardAction.save,
        ),
      );
    },
  );

  switch (action) {
    case _TimerSessionDiscardAction.discard:
      onDiscard();
    case _TimerSessionDiscardAction.save:
      onSave();
    case null:
      onDismissed?.call();
  }
}

class TimerSessionDiscardDialog extends StatelessWidget {
  const TimerSessionDiscardDialog({
    super.key,
    required this.title,
    required this.message,
    required this.discardLabel,
    required this.saveLabel,
    required this.isDark,
    required this.onDiscard,
    required this.onSave,
  });

  final String title;
  final String message;
  final String discardLabel;
  final String saveLabel;
  final bool isDark;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  static const _titleFontSize = 18.0;
  static const _messageFontSize = 14.0;
  static const _buttonFontSize = 15.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final messageColor =
        isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
    final neutralButtonForeground =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Dialog(
      backgroundColor:
          isDark ? AppColors.surfaceDark : AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              strutStyle: context.tibetanStrutStyle(_titleFontSize),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: _titleFontSize,
                letterSpacing: -0.3,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              strutStyle: context.tibetanStrutStyle(_messageFontSize),
              style: textTheme.bodyMedium?.copyWith(
                fontSize: _messageFontSize,
                color: messageColor,
                height: 20 / 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  discardLabel,
                  textAlign: TextAlign.center,
                  strutStyle: context.tibetanStrutStyle(
                    _buttonFontSize,
                    compact: true,
                  ),
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: _buttonFontSize,
                    fontWeight: FontWeight.w400,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSave,
                style: OutlinedButton.styleFrom(
                  foregroundColor: neutralButtonForeground,
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  side: const BorderSide(color: AppColors.grey300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  saveLabel,
                  textAlign: TextAlign.center,
                  strutStyle: context.tibetanStrutStyle(
                    _buttonFontSize,
                    compact: true,
                  ),
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: _buttonFontSize,
                    fontWeight: FontWeight.w400,
                    color: neutralButtonForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
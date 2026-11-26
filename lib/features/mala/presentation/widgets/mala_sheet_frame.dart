import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

/// Shared chrome for the mala bottom sheets: drag handle, a title row with a
/// close button, a divider, then [child] and an optional pinned [footer].
class MalaSheetFrame extends StatelessWidget {
  const MalaSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.trailing,
    this.expand = false,
  });

  final String title;
  final Widget child;

  /// Pinned below [child], e.g. the sheet's primary button.
  final Widget? footer;

  /// Extra action shown before the close button.
  final Widget? trailing;

  /// Give [child] all remaining height (for scrolling grids).
  final bool expand;

  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.cardBackgroundDark
          : AppColors.goldLight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: backgroundOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                  IconButton(
                    icon: const Icon(AppAssets.x, size: 24),
                    tooltip: context.l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.cardBorderDark : AppColors.grey300,
            ),
            if (expand) Expanded(child: child) else child,
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-width black pill button used as a sheet's primary action.
class MalaPrimaryButton extends StatelessWidget {
  const MalaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shows a spinner in place of [label] and ignores taps.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.textPrimaryDark : Colors.black,
          foregroundColor: isDark ? AppColors.textPrimary : Colors.white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child:
            busy
                ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                )
                : Text(label),
      ),
    );
  }
}

/// Short confirmation pill ("✓ Bead style updated") shown over the mala
/// screen after an appearance change. [isError] swaps the check for a
/// warning icon. [bottomMargin] lifts it, e.g. clear of a sheet's button.
void showMalaToast(
  BuildContext context,
  String message, {
  bool isError = false,
  double bottomMargin = 16,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      duration: const Duration(seconds: 2),
      content: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const ShapeDecoration(
            color: Colors.black,
            shape: StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? AppAssets.warningCircle : AppAssets.check,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Hosts a mala sheet in its own [ScaffoldMessenger], so a toast shown from
/// inside the sheet (such as a failed save) appears above it, not behind it.
class MalaSheetToastHost extends StatelessWidget {
  const MalaSheetToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: child,
      ),
    );
  }
}

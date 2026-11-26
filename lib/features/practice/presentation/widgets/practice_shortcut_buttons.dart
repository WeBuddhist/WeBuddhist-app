import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Mala and Timer buttons on the Practice tab. They open the same screens
/// as the Home shortcuts, and a guest is asked to sign in first.
class PracticeShortcutButtons extends ConsumerWidget {
  const PracticeShortcutButtons({super.key});

  void _openMala(BuildContext context, WidgetRef ref) {
    if (ref.read(authProvider).isGuest) {
      LoginDrawer.show(context, ref, feature: 'mala');
      return;
    }
    context.push('/mala', extra: {'source': MalaOpenSource.practiceTab});
  }

  void _openTimers(BuildContext context, WidgetRef ref) {
    if (ref.read(authProvider).isGuest) {
      LoginDrawer.show(context, ref, feature: 'timer');
      return;
    }
    context.push('/home/timers');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _ShortcutButton(
              label: l10n.home_mala,
              imageAsset: AppAssets.homeMalaIcon,
              onTap: () => _openMala(context, ref),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ShortcutButton(
              label: l10n.home_timer,
              icon: AppAssets.homeTimer,
              onTap: () => _openTimers(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.imageAsset,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? imageAsset;

  static const _radius = 12.0;
  static const _height = 44.0;
  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Material(
      color: isDark ? AppColors.cardBackgroundDark : Colors.white,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imageAsset != null)
                Image.asset(
                  imageAsset!,
                  width: _iconSize,
                  height: _iconSize,
                  color: foreground,
                  colorBlendMode: BlendMode.srcIn,
                )
              else if (icon != null)
                Icon(icon, size: _iconSize, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
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

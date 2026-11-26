import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/tibetan_numerals.dart';

/// The "My practices" pill on Home and the Practice tab: the title, how
/// many practices the member keeps (or "Start a routine" with none yet),
/// and an arrow into My practices.
class MyPracticesStatsCard extends StatelessWidget {
  const MyPracticesStatsCard({super.key, required this.count, this.onTap});

  /// Plans and chants together; null when they couldn't be read, which
  /// leaves the count out rather than showing a wrong 0.
  final int? count;
  final VoidCallback? onTap;

  static const borderRadius = 14.0;
  static const minHeight = 52.0;
  static const _titleFontSize = 16.0;
  static const _countFontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final countLabel =
        count == null
            ? null
            : count == 0
            ? context.l10n.practice_start_routine
            : context.l10n.home_practices_sessions(count);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.myPracticesBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Grows past the pill height rather than clipping at large text.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.routine_title,
                      strutStyle: context.tibetanStrutStyle(
                        _titleFontSize,
                        compact: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: _titleFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (countLabel != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      context.isTibetanLocale
                          ? toTibetanDigits(countLabel)
                          : countLabel,
                      strutStyle: context.tibetanStrutStyle(
                        _countFontSize,
                        compact: true,
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: _countFontSize,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  const _ArrowBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White circle with an arrow; decoration only, the whole pill is the tap
/// target.
class _ArrowBadge extends StatelessWidget {
  const _ArrowBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(AppAssets.arrowRight, color: AppColors.blue, size: 18),
      ),
    );
  }
}

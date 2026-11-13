import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';

/// Small muted heading above a group of timers ("Your timers", presets).
/// Upper-cased except in Tibetan, which has no letter case.
class TimerSectionTitle extends StatelessWidget {
  const TimerSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isTibetan = AppFontConfig.isTibetanLanguage(
      Localizations.localeOf(context).languageCode,
    );
    final color =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.textTertiaryDark
            : AppColors.grey800;

    return Text(
      isTibetan ? title : title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: isTibetan ? 0 : 0.72,
        color: color,
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter_pecha/core/constants/app_config.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';

/// Taglines shown on the splash screen; one is picked at random per launch.
final List<String Function(AppLocalizations)> splashTaglines = [
  (l10n) => l10n.splash_tagline_1,
  (l10n) => l10n.splash_tagline_2,
];

int randomSplashTaglineIndex([Random? random]) {
  final rng = random ?? Random();
  return rng.nextInt(splashTaglines.length);
}

/// Line height for a translated (non-English) splash tagline in
/// [languageCode]. Scripts with tall stacked marks need more room between
/// lines once the tagline wraps, or the lines collide.
double splashTaglineLineHeight(String languageCode) {
  if (AppFontConfig.isTibetanLanguage(languageCode)) {
    return AppFontConfig.tibetanUiLineHeight;
  }
  return switch (languageCode.toLowerCase()) {
    AppConfig.burmeseLanguageCode => 1.8,
    AppConfig.thaiLanguageCode => 1.7,
    AppConfig.hindiLanguageCode || AppConfig.nepaliLanguageCode => 1.6,
    _ => 1.4,
  };
}

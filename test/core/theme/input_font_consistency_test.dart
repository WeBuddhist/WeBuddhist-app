import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_config.dart';
import 'package:flutter_pecha/core/theme/app_theme.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// User-entered text (and its placeholder) is system UI, so it must use the
/// system (sans) font, never the content (serif) font. Regression guard for
/// #1140, where the calendar's event-name hint rendered in the content font.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Only Tibetan: its fonts are bundled, so the theme builds offline. The
  // en/zh themes use Google Fonts, which try to download in tests. The hint
  // style does not depend on the locale, so one locale covers it.
  const languages = [AppConfig.tibetanLanguageCode];

  for (final language in languages) {
    for (final brightness in Brightness.values) {
      test('input hint does not use the content font ($language, '
          '${brightness.name})', () {
        final theme =
            brightness == Brightness.light
                ? AppTheme.lightTheme(Locale(language))
                : AppTheme.darkTheme(Locale(language));
        final config = AppFontConfig.getConfig(language);
        String squash(String? f) =>
            (f ?? '').replaceAll(' ', '').toLowerCase();

        // The hint sets no family of its own, so it inherits the field's
        // text style and matches what the user types.
        expect(theme.inputDecorationTheme.hintStyle?.fontFamily, isNull);
        // The field's text comes from the system text theme, which must not
        // be the content font. Google Fonts register names like
        // "SourceSerif4_regular", hence the prefix check.
        expect(
          squash(theme.textTheme.bodyLarge?.fontFamily),
          isNot(startsWith(squash(config.contentFont))),
        );
      });
    }
  }
}

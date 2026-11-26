import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations_en.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter_pecha/features/auth/presentation/screens/splash_taglines.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Flutter SDK, which ships the Roboto fonts used as a stand-in for a
/// late-arriving Inter.
String _flutterRoot() =>
    Platform.environment['FLUTTER_ROOT'] ??
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;

void main() {
  const tagline = 'We Buddhists learn daily';

  double opacityOf(WidgetTester tester, String text) {
    return tester
        .widget<Opacity>(
          find
              .ancestor(of: find.text(text), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
  }

  /// Rendered logo width, i.e. its intrinsic 144 under the intro scale.
  double logoWidth(WidgetTester tester) =>
      tester.getRect(find.byType(Image)).width;

  test('randomSplashTaglineIndex picks from the tagline list', () {
    final seen = <int>{};
    for (var i = 0; i < 200; i++) {
      seen.add(randomSplashTaglineIndex(Random(i)));
    }
    expect(seen, everyElement(inInclusiveRange(0, splashTaglines.length - 1)));
    expect(seen.length, greaterThan(1));
  });

  testWidgets('plays the intro: logo grows, wordmark splits into the tagline', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          tagline: tagline,
          onIntroComplete: () => completed = true,
        ),
      ),
    );

    // First frame: the small launch logo, nothing else visible yet.
    expect(find.byType(Image), findsOneWidget);
    expect(logoWidth(tester), closeTo(60, 0.01));
    final row = tester.widget<Opacity>(
      find.ancestor(of: find.text('We'), matching: find.byType(Opacity)).last,
    );
    expect(row.opacity, 0);

    // Logo has grown and the wordmark "WeBuddhist" is in: the two words touch.
    await tester.pump(const Duration(milliseconds: 600));
    expect(logoWidth(tester), closeTo(144, 0.01));
    expect(
      tester.getRect(find.text('Buddhist')).left,
      closeTo(tester.getRect(find.text('We')).right, 0.5),
    );
    expect(opacityOf(tester, 's'), 0);
    expect(opacityOf(tester, 'learn daily'), 0);

    // Words have settled: "We Buddhists" with a space and the plural "s".
    await tester.pump(const Duration(milliseconds: 1400));
    expect(
      tester.getRect(find.text('Buddhist')).left,
      greaterThan(tester.getRect(find.text('We')).right + 2),
    );
    expect(opacityOf(tester, 's'), 1);
    expect(opacityOf(tester, 'learn daily'), 0);

    // The rest slid in; the whole tagline is centred.
    await tester.pump(const Duration(milliseconds: 550));
    expect(opacityOf(tester, 'learn daily'), 1);
    final left = tester.getRect(find.text('We')).left;
    final right = tester.getRect(find.text('learn daily')).right;
    final screen = tester.getSize(find.byType(Scaffold));
    expect((left + right) / 2, closeTo(screen.width / 2, 1));
    expect(completed, isFalse);

    // Final hold, then the intro reports completion (the controller finishes
    // on the first tick past its duration).
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 16));
    expect(completed, isTrue);

    // The logo holds still while the next screen fades in, then pulses.
    await tester.pump(const Duration(milliseconds: 500));
    expect(logoWidth(tester), closeTo(144, 0.01));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(logoWidth(tester), greaterThan(144.5));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reads as one sentence to assistive technology', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(tagline: tagline)),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.bySemanticsLabel(tagline), findsOneWidget);
    handle.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('skips the intro when playIntro is false', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          tagline: tagline,
          playIntro: false,
          onIntroComplete: () => completed = true,
        ),
      ),
    );
    await tester.pump();
    expect(completed, isTrue);
    expect(logoWidth(tester), closeTo(144, 0.01));
    expect(opacityOf(tester, 's'), 1);
    expect(opacityOf(tester, 'learn daily'), 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('skips the intro when animations are disabled', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SplashScreen(
            tagline: tagline,
            onIntroComplete: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(completed, isTrue);
    expect(opacityOf(tester, 'learn daily'), 1);

    // Past the pulse delay the logo still does not pulse.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(logoWidth(tester), 144);
    }
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('re-measures the tagline when its font arrives late', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(tagline: tagline, playIntro: false)),
    );
    await tester.pump();

    final family = GoogleFonts.inter(fontWeight: FontWeight.w700).fontFamily!;
    final roboto = File(
      '${_flutterRoot()}/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf',
    ).readAsBytesSync();
    await tester.runAsync(() async {
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.view(roboto.buffer))))
          .load();
    });
    await tester.pump();

    final space =
        TextPainter(
            text: TextSpan(
              text: ' ',
              style: TextStyle(
                fontFamily: family,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
          )
          ..layout();
    final gap =
        tester.getRect(find.text('Buddhist')).left -
        tester.getRect(find.text('We')).right;
    expect(gap, closeTo(space.width, 1));
    space.dispose();
  });

  testWidgets('reports completion if removed before the intro ends', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          tagline: tagline,
          onIntroComplete: () => completed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, isFalse);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets(
    'cross-fades to a tagline that does not grow out of the wordmark',
    (tester) async {
      const other = 'Practice daily, together';
      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen(tagline: other)),
      );
      expect(find.text('WeBuddhist'), findsOneWidget);
      expect(find.text(other), findsOneWidget);
      expect(find.text('We'), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      expect(opacityOf(tester, 'WeBuddhist'), 1);
      expect(opacityOf(tester, other), 0);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(opacityOf(tester, 'WeBuddhist'), 0);
      expect(opacityOf(tester, other), 1);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('picks a tagline from the list when none is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashScreen(),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizationsEn();
    final rest = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .where((word) => word.startsWith('practice'));
    expect(rest, hasLength(1));
    expect(
      splashTaglines.map((tagline) => tagline(l10n)),
      contains('We Buddhists ${rest.single}'),
    );
    await tester.pump(const Duration(seconds: 4));
  });

  Future<void> pumpThemed(
    WidgetTester tester, {
    required Brightness phone,
    required ThemeMode app,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = phone;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: app,
        home: const SplashScreen(tagline: tagline),
      ),
    );
  }

  testWidgets('follows the app theme set to light on a dark phone', (
    tester,
  ) async {
    await pumpThemed(tester, phone: Brightness.dark, app: ThemeMode.light);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.surfaceLight);
    final text = tester.widget<Text>(find.text('We'));
    expect(text.style?.color, AppColors.textPrimary);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('follows the app theme set to dark on a light phone', (
    tester,
  ) async {
    await pumpThemed(tester, phone: Brightness.light, app: ThemeMode.dark);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.backgroundDark);
    final text = tester.widget<Text>(find.text('We'));
    expect(text.style?.color, AppColors.textPrimaryDark);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('follows the phone when the app theme is system', (
    tester,
  ) async {
    await pumpThemed(tester, phone: Brightness.dark, app: ThemeMode.system);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.backgroundDark);
    await tester.pump(const Duration(seconds: 4));
  });

  test('splashTaglineLineHeight gives tall scripts more room', () {
    expect(splashTaglineLineHeight('bo'), AppFontConfig.tibetanUiLineHeight);
    expect(splashTaglineLineHeight('my'), 1.8);
    expect(splashTaglineLineHeight('th'), 1.7);
    expect(splashTaglineLineHeight('hi'), 1.6);
    expect(splashTaglineLineHeight('ne'), 1.6);
    expect(splashTaglineLineHeight('mn'), 1.4);
    expect(splashTaglineLineHeight('zh'), 1.4);
    expect(splashTaglineLineHeight('en'), 1.4);
  });

  test('every locale translates both taglines', () {
    final arbs =
        Directory('lib/core/l10n')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .toList();
    expect(arbs, isNotEmpty);
    final english =
        jsonDecode(File('lib/core/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final arb in arbs) {
      if (arb.path.endsWith('app_en.arb')) continue;
      final strings =
          jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
      for (final key in ['splash_tagline_1', 'splash_tagline_2']) {
        expect(strings[key], isA<String>(), reason: '$key in ${arb.path}');
        expect(
          strings[key],
          isNot(english[key]),
          reason: '$key in ${arb.path} is still English',
        );
      }
    }
  });

  testWidgets('draws a translated Latin-script tagline in the bold font file', (
    tester,
  ) async {
    const vietnamese = 'Phật tử chúng ta cùng nhau tu tập';
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashScreen(tagline: vietnamese, playIntro: false),
      ),
    );
    await tester.pump();

    final style = tester.widget<Text>(find.text(vietnamese)).style!;
    expect(style.fontWeight, FontWeight.w700);
    // Google Fonts names each weight's file; the bold one, not the regular.
    expect(
      style.fontFamily,
      GoogleFonts.inter(fontWeight: FontWeight.w700).fontFamily,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('wraps a Burmese tagline with room between its lines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const burmese = 'ဗုဒ္ဓဘာသာဝင် ကျွန်ုပ်တို့ အတူတကွ ကျင့်ကြံကြသည်';

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('my'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashScreen(tagline: burmese, playIntro: false),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text(burmese));
    expect(text.style?.height, 1.8);
    expect(text.textAlign, TextAlign.center);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(burmese),
    );
    // Wraps rather than overflowing, each line 1.8× the font size.
    expect(paragraph.size.height, greaterThanOrEqualTo(2 * 20 * 1.8 - 0.5));
    expect(paragraph.size.width, lessThanOrEqualTo(320 - 2 * 32));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('shows a full tagline line in a short viewport with large text', (
    tester,
  ) async {
    const long =
        'We Buddhists know that things are our own projections, not the way they look.';
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(3)),
          child: SplashScreen(tagline: long),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // Does not fit on one line, so it is not split into animated words.
    expect(find.text('We'), findsNothing);

    await tester.ensureVisible(find.text(long));
    await tester.pump();
    final rect = tester.getRect(find.text(long));
    final lineHeight =
        tester
            .renderObject<RenderParagraph>(find.text(long))
            .preferredLineHeight;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.top + lineHeight, lessThanOrEqualTo(200));
    await tester.pump(const Duration(seconds: 1));
  });
}

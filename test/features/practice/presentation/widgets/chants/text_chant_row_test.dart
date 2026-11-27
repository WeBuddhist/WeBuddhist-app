import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int taps;
  late int mores;

  Future<void> pump(WidgetTester tester, {bool withMore = true}) async {
    taps = 0;
    mores = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TextChantRow(
            title: 'Praise to Tara',
            openLabel: 'Open chant',
            onTap: () => taps++,
            onMore: withMore ? () => mores++ : null,
          ),
        ),
      ),
    );
  }

  testWidgets('the ⋮ sits beside the arrow and starts a chant book', (
    tester,
  ) async {
    await pump(tester);

    final arrow = find.byIcon(AppAssets.caretRight);
    final more = find.byIcon(AppAssets.dotsThreeVerticalBold);
    expect(arrow, findsOneWidget);
    expect(more, findsOneWidget);
    expect(tester.getCenter(more).dx, greaterThan(tester.getCenter(arrow).dx));
    expect(find.bySemanticsLabel('Add to chant book'), findsOneWidget);

    await tester.tap(more);
    expect(mores, 1);
    expect(taps, 0);

    await tester.tap(arrow);
    expect(taps, 1);
    expect(mores, 1);
  });

  testWidgets('a long-press starts a chant book; a tap still opens it', (
    tester,
  ) async {
    await pump(tester);

    await tester.longPress(find.text('Praise to Tara'));
    expect(mores, 1);
    expect(taps, 0);

    await tester.tap(find.text('Praise to Tara'));
    expect(taps, 1);
    expect(mores, 1);
  });

  testWidgets('without onMore the row keeps its open arrow', (tester) async {
    await pump(tester, withMore: false);

    expect(find.byIcon(AppAssets.dotsThreeVerticalBold), findsNothing);
    expect(find.bySemanticsLabel('Add to chant book'), findsNothing);

    await tester.tap(find.byIcon(AppAssets.caretRight));
    expect(taps, 1);
  });
}

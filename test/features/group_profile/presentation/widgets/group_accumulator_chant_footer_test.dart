import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_accumulator_chant_footer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> taps;

  setUp(() => taps = []);

  Widget app({
    int completedCount = 4,
    bool canCount = true,
    bool isFinishing = false,
  }) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: GroupAccumulatorChantFooter(
          completedCount: completedCount,
          canCount: canCount,
          isFinishing: isFinishing,
          onReciteAgain: () => taps.add('again'),
          onFinishAndCount: () => taps.add('finishCount'),
          onFinishWithoutCounting: () => taps.add('finishNoCount'),
        ),
      ),
    ),
  );

  testWidgets('shows the recitations completed in this visit', (tester) async {
    await tester.pumpWidget(app(completedCount: 4));

    expect(find.text('You completed recitations'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('group_accumulator_completed_count')),
          )
          .data,
      '4',
    );
  });

  testWidgets('each action calls its own callback', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Recite again'));
    await tester.tap(find.text('Finish and count'));
    await tester.tap(find.text('Finish without counting'));

    expect(taps, ['again', 'finishCount', 'finishNoCount']);
  });

  testWidgets(
    'while the target cannot take a count, only finishing without counting works',
    (tester) async {
      await tester.pumpWidget(app(canCount: false));

      await tester.tap(find.text('Recite again'));
      await tester.tap(find.text('Finish and count'));
      await tester.tap(find.text('Finish without counting'));

      expect(taps, ['finishNoCount']);
    },
  );

  testWidgets('while finishing, no action can be tapped', (tester) async {
    await tester.pumpWidget(app(isFinishing: true));

    await tester.tap(find.text('Recite again'));
    await tester.tap(find.text('Finish and count'));
    await tester.tap(find.text('Finish without counting'));

    expect(taps, isEmpty);
  });
}

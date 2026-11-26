import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/home/domain/entities/routine_info.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/my_practices_stats_card.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int? count,
  String locale = 'en',
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MyPracticesStatsCard(count: count, onTap: onTap)),
    ),
  );
}

void main() {
  test('the count is plans and chants together', () {
    const info = RoutineInfo(seriesCount: 3, recitationCount: 7);
    expect(info.totalCount, 10);
    expect(const RoutineInfo(seriesCount: 0, recitationCount: 0).totalCount, 0);
  });

  testWidgets('shows the title and the session count', (tester) async {
    await _pump(tester, count: 10);
    expect(find.text('My practices'), findsOneWidget);
    expect(find.text('10 sessions'), findsOneWidget);
  });

  testWidgets('invites to start a routine at 0, shows 1', (tester) async {
    await _pump(tester, count: 0);
    expect(find.text('Start a routine'), findsOneWidget);
    expect(find.textContaining('session'), findsNothing);

    await _pump(tester, count: 1);
    expect(find.text('1 session'), findsOneWidget);
  });

  testWidgets('leaves the count out when it is unknown', (tester) async {
    await _pump(tester, count: null);
    expect(find.text('My practices'), findsOneWidget);
    expect(find.textContaining('session'), findsNothing);
  });

  testWidgets('Tibetan shows Tibetan digits', (tester) async {
    await _pump(tester, count: 12, locale: 'bo');
    expect(find.text('ཐུན་ ༡༢'), findsOneWidget);
  });

  testWidgets('the whole pill opens My practices', (tester) async {
    var taps = 0;
    await _pump(tester, count: 2, onTap: () => taps++);
    await tester.tap(find.text('My practices'));
    await tester.tap(find.text('2 sessions'));
    expect(taps, 2);
  });
}

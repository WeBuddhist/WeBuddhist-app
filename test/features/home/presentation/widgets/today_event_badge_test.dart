import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/constants/app_config.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/today_event_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const one = TodayEventBadgeItem(id: 'e1', name: 'tara puja', isLive: true);
  const two = TodayEventBadgeItem(id: 'e2', name: 'medicine buddha puja');
  const three = TodayEventBadgeItem(id: 'e3', name: 'morning meditation');

  Future<void> pump(
    WidgetTester tester, {
    required List<TodayEventBadgeItem> events,
    ValueChanged<String>? onSelect,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayEventBadge(events: events, onSelect: onSelect),
        ),
      ),
    );
  }

  testWidgets('a single event opens directly on tap', (tester) async {
    final selected = <String>[];
    await pump(tester, events: [one], onSelect: selected.add);

    expect(find.text('Tara Puja'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.text('Tara Puja'));
    await tester.pump();

    expect(selected, ['e1']);
  });

  testWidgets('several events show a count and drop down the list', (
    tester,
  ) async {
    final selected = <String>[];
    await pump(tester, events: [one, two, three], onSelect: selected.add);

    expect(find.text('Tara Puja'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Medicine Buddha Puja'), findsNothing);
    // Collapsed pill stacks one avatar per event.
    expect(find.byIcon(AppAssets.usersThree), findsNWidgets(3));

    await tester.tap(find.text('Tara Puja'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, isEmpty);
    expect(find.text('Tara Puja'), findsNWidgets(2));
    expect(find.text('Medicine Buddha Puja'), findsOneWidget);
    expect(find.text('Morning Meditation'), findsOneWidget);

    await tester.tap(find.text('Morning Meditation'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, ['e3']);
    expect(find.text('Morning Meditation'), findsNothing);
  });

  testWidgets('the open list marks every live event and no others', (
    tester,
  ) async {
    final liveDot = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_LiveDot',
    );
    const alsoLive = TodayEventBadgeItem(
      id: 'e4',
      name: 'evening prayers',
      isLive: true,
    );
    await pump(tester, events: [one, alsoLive, two]);

    // Collapsed: only the pill's own event.
    expect(liveDot, findsOneWidget);

    await tester.tap(find.text('Tara Puja'));
    await tester.pump(const Duration(milliseconds: 300));

    // Pill plus the two live rows; the upcoming row has none.
    expect(liveDot, findsNWidgets(3));
    final upcomingRow = find.ancestor(
      of: find.text('Medicine Buddha Puja'),
      matching: find.byType(MenuItemButton),
    );
    expect(find.descendant(of: upcomingRow, matching: liveDot), findsNothing);
    // In a live row the dot sits at the right edge, after the name.
    final liveRow = find.ancestor(
      of: find.text('Evening Prayers'),
      matching: find.byType(MenuItemButton),
    );
    final rowDot = find.descendant(of: liveRow, matching: liveDot);
    expect(rowDot, findsOneWidget);
    expect(
      tester.getCenter(rowDot).dx,
      greaterThan(tester.getTopRight(find.text('Evening Prayers')).dx),
    );
  });

  testWidgets('no dots when nothing is live yet', (tester) async {
    final liveDot = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_LiveDot',
    );
    await pump(tester, events: [two, three]);

    await tester.tap(find.text('Medicine Buddha Puja'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Medicine Buddha Puja'), findsNWidgets(2));
    expect(liveDot, findsNothing);
  });

  testWidgets('a Tibetan name uses the Tibetan font in English mode', (
    tester,
  ) async {
    const tibetan = TodayEventBadgeItem(
      id: 'e5',
      name: 'ཚོད་ལྟ།',
      isLive: true,
    );
    await pump(tester, events: [one, tibetan]);

    await tester.tap(find.text('Tara Puja'));
    await tester.pump(const Duration(milliseconds: 300));

    final name = tester.widget<Text>(find.text('ཚོད་ལྟ།'));
    expect(name.style?.fontFamily, AppConfig.tibetanContentFont);
    final english = tester.widget<Text>(find.text('Tara Puja').first);
    expect(english.style?.fontFamily, isNot(AppConfig.tibetanContentFont));
  });
}

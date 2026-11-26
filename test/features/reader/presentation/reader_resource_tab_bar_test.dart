import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_pecha/features/reader/data/models/reader_state.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_actions/reader_verse_sheet.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_settings/reader_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_local_storage.dart';

String _label(ReaderResourceTab tab) => switch (tab) {
  ReaderResourceTab.commentary => 'Commentary',
  ReaderResourceTab.versions => 'Versions',
  ReaderResourceTab.videos => 'Videos',
  ReaderResourceTab.rootText => 'Root text',
};

Future<List<ReaderResourceTab>> _pump(
  WidgetTester tester,
  List<ReaderResourceTab> tabs,
) async {
  final tapped = <ReaderResourceTab>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(FakeLocalStorage()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ReaderResourceTabBar(
                tabs: tabs,
                selected: tabs.isEmpty ? null : tabs.first,
                labelOf: _label,
                onSelected: tapped.add,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return tapped;
}

void main() {
  group("a verse sheet's tab row (#1146)", () {
    testWidgets('a verse with one resource names it in a plain label', (
      tester,
    ) async {
      final tapped = await _pump(tester, const [ReaderResourceTab.versions]);
      expect(find.byType(ReaderSheetSegments<ReaderResourceTab>), findsNothing);
      expect(find.text('Versions'), findsOneWidget);
      // Not a button: a tap does nothing.
      await tester.tap(find.text('Versions'));
      expect(tapped, isEmpty);
    });

    testWidgets('a verse with two or more resources gets the segments', (
      tester,
    ) async {
      final tapped = await _pump(tester, const [
        ReaderResourceTab.commentary,
        ReaderResourceTab.versions,
        ReaderResourceTab.videos,
      ]);
      expect(
        find.byType(ReaderSheetSegments<ReaderResourceTab>),
        findsOneWidget,
      );
      await tester.tap(find.text('Videos'));
      expect(tapped, [ReaderResourceTab.videos]);
    });

    testWidgets('a verse with none shows no row', (tester) async {
      await _pump(tester, const []);
      expect(find.byType(ReaderSheetSegments<ReaderResourceTab>), findsNothing);
      for (final tab in ReaderResourceTab.values) {
        expect(find.text(_label(tab)), findsNothing);
      }
    });
  });
}

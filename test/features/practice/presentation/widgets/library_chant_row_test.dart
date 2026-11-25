import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/library_chant_row.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  testWidgets('a recorded chant shows the play button, which plays', (
    tester,
  ) async {
    final opens = <bool>[];
    await tester.pumpWidget(
      _app(
        LibraryChantRow(
          chant: RecitationModel(
            textId: 'E1',
            title: 'Recorded',
            language: 'en',
            hasAudio: true,
          ),
          onOpen: ({required bool play}) => opens.add(play),
        ),
      ),
    );

    expect(find.byType(AudioChantRow), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(en.player_play));
    await tester.tap(find.text('Recorded'));

    expect(opens, [true, false]);
  });

  testWidgets('a chant without audio stays a text row', (tester) async {
    final opens = <bool>[];
    await tester.pumpWidget(
      _app(
        LibraryChantRow(
          chant: RecitationModel(textId: 'E2', title: 'Silent', language: 'en'),
          onOpen: ({required bool play}) => opens.add(play),
        ),
      ),
    );

    expect(find.byType(TextChantRow), findsOneWidget);
    expect(find.byType(AudioChantRow), findsNothing);
    await tester.tap(find.text('Silent'));

    expect(opens, [false]);
  });
}

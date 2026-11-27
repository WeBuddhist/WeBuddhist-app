import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/my_recitation_collections_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/add_to_chant_book_sheet.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/collection_name_dialog.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

Widget _app(Widget home, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  group('New chant book sheet', () {
    testWidgets('starts empty with a placeholder; Create waits for a name', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showCollectionNameSheet(
                        context,
                        title: 'New chant book',
                        actionLabel: 'Create',
                        hintText: 'Chant book name',
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(find.text('Chant book name'), findsOneWidget);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('New chant book'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(find.byType(TextField), ' Morning refuge ');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result, 'Morning refuge');
    });
  });

  group('AudioChantRow', () {
    testWidgets('⋮ follows the play button; it and a long-press call onMore', (
      tester,
    ) async {
      var mores = 0;
      var plays = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AudioChantRow(
              title: 'Refuge',
              playLabel: 'Play',
              onTap: () {},
              onPlay: () => plays++,
              onMore: () => mores++,
            ),
          ),
        ),
      );

      final play = find.byIcon(AppAssets.play);
      final more = find.byIcon(AppAssets.dotsThreeVerticalBold);
      expect(tester.getCenter(more).dx, greaterThan(tester.getCenter(play).dx));
      expect(find.bySemanticsLabel('Add to chant book'), findsOneWidget);

      await tester.tap(more);
      await tester.longPress(find.text('Refuge'));
      expect(mores, 2);
      expect(plays, 0);
    });

    testWidgets('without onMore there is no ⋮', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(body: AudioChantRow(title: 'Refuge', playLabel: '')),
        ),
      );
      expect(find.byIcon(AppAssets.dotsThreeVerticalBold), findsNothing);
    });
  });

  group('AddToChantBookSheet', () {
    final chant = RecitationModel(textId: 't1', title: 'Refuge');

    Future<AddToChantBookChoice?> openSheet(
      WidgetTester tester,
      List<MyRecitationCollectionModel> books,
      Future<void> Function() pick,
    ) async {
      AddToChantBookChoice? choice;
      await tester.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      choice = await showAddToChantBookSheet(
                        context,
                        chant: chant,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
          ),
          overrides: [
            ownChantBooksProvider.overrideWith((ref) async => Right(books)),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await pick();
      await tester.pumpAndSettle();
      return choice;
    }

    testWidgets('shows the chant and New chant book picks a new book', (
      tester,
    ) async {
      final choice = await openSheet(tester, const [], () async {
        expect(find.text('Add to chant book'), findsOneWidget);
        expect(find.text('Refuge'), findsOneWidget);
        expect(find.text('Your chant books'), findsNothing);
        await tester.tap(find.text('New chant book'));
      });
      expect(choice, isA<NewChantBookChoice>());
    });

    testWidgets('closing it picks nothing', (tester) async {
      final choice = await openSheet(tester, const [], () async {
        await tester.tap(find.byIcon(AppAssets.x));
      });
      expect(choice, isNull);
    });
  });
}

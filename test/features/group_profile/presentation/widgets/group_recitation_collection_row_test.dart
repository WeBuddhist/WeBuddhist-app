import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_recitation_collection_row.dart';
import 'package:flutter_pecha/features/library/data/models/library_recording.dart';
import 'package:flutter_pecha/features/library/presentation/providers/library_providers.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GroupRecitationCollectionItem _item(String id, {String? textId}) =>
    GroupRecitationCollectionItem(
      id: id,
      textId: textId ?? 'edition-$id',
      title: 'Chant $id',
      language: 'bo',
      type: '',
      displayOrder: 0,
    );

void main() {
  group('GroupRecitationCollectionRow', () {
    final asked = <String>[];

    Future<void> pump(
      WidgetTester tester,
      GroupRecitationCollectionItem item, {
      required FutureOr<List<LibraryRecording>> Function(String id) recordings,
      VoidCallback? onPlay,
      VoidCallback? onTap,
    }) async {
      asked.clear();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chantRecordingsProvider.overrideWith((ref, id) {
              asked.add(id);
              return recordings(id);
            }),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: GroupRecitationCollectionRow(
                item: item,
                isDark: false,
                isCompleted: false,
                isSubmitting: false,
                onTap: onTap ?? () {},
                onPlay: onPlay,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows play when the library has a recording', (tester) async {
      var played = 0;
      await pump(
        tester,
        _item('a'),
        recordings: (_) => const [LibraryRecording(id: 'rec-1')],
        onPlay: () => played++,
      );

      expect(asked, ['edition-a']);
      expect(find.byIcon(AppAssets.play), findsOneWidget);
      expect(find.byIcon(AppAssets.caretRight), findsNothing);

      await tester.tap(find.byIcon(AppAssets.play));
      expect(played, 1);
    });

    testWidgets('shows the caret when the text has no recording', (
      tester,
    ) async {
      var opened = 0;
      await pump(
        tester,
        _item('a'),
        recordings: (_) => const [],
        onPlay: () => fail('no recording to play'),
        onTap: () => opened++,
      );

      expect(find.byIcon(AppAssets.play), findsNothing);
      expect(find.byIcon(AppAssets.caretRight), findsOneWidget);

      await tester.tap(find.text('Chant a'));
      expect(opened, 1);
    });

    testWidgets('keeps the caret while recordings load or if they fail', (
      tester,
    ) async {
      final pending = Completer<List<LibraryRecording>>();
      await pump(
        tester,
        _item('a'),
        recordings: (_) => pending.future,
        onPlay: () {},
      );
      expect(find.byIcon(AppAssets.caretRight), findsOneWidget);

      pending.completeError(Exception('library down'));
      await tester.pump();
      expect(find.byIcon(AppAssets.caretRight), findsOneWidget);
      expect(find.byIcon(AppAssets.play), findsNothing);
    });

    testWidgets('a chant without a text id asks the library nothing', (
      tester,
    ) async {
      await pump(
        tester,
        _item('a', textId: '  '),
        recordings: (_) => const [LibraryRecording(id: 'rec-1')],
        onPlay: () {},
      );

      expect(asked, isEmpty);
      expect(find.byIcon(AppAssets.caretRight), findsOneWidget);
    });
  });

  group('groupRecitationCollectionNavigationContext', () {
    final collection = GroupRecitationCollection(
      id: 'c',
      groupId: 'g',
      name: 'Morning',
      imageUrl: 'https://cdn/cover.jpg',
      items: [_item('a'), _item('b')],
    );
    const key = GroupRecitationCollectionKey(groupId: 'g', collectionId: 'c');

    test('play asks the reader to start the first recording', () {
      final context = groupRecitationCollectionNavigationContext(
        key: key,
        collection: collection,
        item: collection.items[1],
        completionState: const GroupRecitationCollectionCompletionState(),
        play: true,
        groupName: 'Sangha',
      );

      expect(context.source, NavigationSource.groupRecitationCollection);
      expect(context.autoPlay, isTrue);
      expect(context.playsChantRecordings, isTrue);
      expect(context.currentTextIndex, 1);
      expect(context.planTextItems!.map((i) => i.textId), [
        'edition-a',
        'edition-b',
      ]);
      expect(context.groupTitle, 'Sangha');
      expect(context.collectionImageUrl, 'https://cdn/cover.jpg');
    });

    test('opening a chant without play does not autoplay', () {
      final context = groupRecitationCollectionNavigationContext(
        key: key,
        collection: collection,
        item: collection.items.first,
        completionState: const GroupRecitationCollectionCompletionState(),
      );
      expect(context.autoPlay, isFalse);
    });
  });
}

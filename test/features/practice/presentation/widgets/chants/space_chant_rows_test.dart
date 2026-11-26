import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/library/data/models/library_recording.dart';
import 'package:flutter_pecha/features/library/presentation/providers/library_providers.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/space_chant_rows.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

SpaceChant _chant() {
  const item = GroupRecitationCollectionItem(
    id: 'chant-1',
    textId: 'edition-1',
    title: 'Praise to Tara',
    language: 'en',
    type: '',
    displayOrder: 0,
  );
  return const SpaceChant(
    item: item,
    collection: GroupRecitationCollection(
      id: 'c',
      groupId: 'g',
      name: 'Morning',
      items: [item],
    ),
    spaceName: 'Sangha',
    hasAudio: true,
  );
}

void main() {
  late List<Object?> opened;

  Future<void> pump(
    WidgetTester tester, {
    required FutureOr<List<LibraryRecording>> Function(String id) recordings,
  }) async {
    opened = [];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (_, __) => Scaffold(body: SpaceAudioChantRow(chant: _chant())),
        ),
        GoRoute(
          path: '/reader/:textId',
          builder: (_, state) {
            opened.add(state.pathParameters['textId']);
            opened.add(state.extra);
            return const Scaffold(body: Text('reader'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chantRecordingsProvider.overrideWith((ref, id) => recordings(id)),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the line under the title is the first recording\'s title', (
    tester,
  ) async {
    await pump(
      tester,
      recordings:
          (_) => const [
            LibraryRecording(id: 'rec-1', title: {'en': 'With music.m4a'}),
            LibraryRecording(id: 'rec-2', title: {'en': 'Voice only'}),
          ],
    );

    expect(find.text('Praise to Tara'), findsOneWidget);
    // The file ending is dropped, as for studio titles before.
    expect(find.text('With music'), findsOneWidget);
    expect(find.text('Voice only'), findsNothing);
  });

  testWidgets('no line while recordings load or when there are none', (
    tester,
  ) async {
    await pump(tester, recordings: (_) => const []);
    expect(find.byIcon(AppAssets.chantAudio), findsNothing);
  });

  testWidgets('play opens the reader asking it to start a recording', (
    tester,
  ) async {
    await pump(
      tester,
      recordings: (_) => const [LibraryRecording(id: 'rec-1')],
    );

    await tester.tap(find.byIcon(AppAssets.play));
    await tester.pumpAndSettle();

    expect(opened.first, 'edition-1');
    final context = opened.last as NavigationContext;
    expect(context.source, NavigationSource.groupRecitationCollection);
    expect(context.autoPlay, isTrue);
    expect(context.groupTitle, 'Sangha');
  });

  testWidgets('tapping the row opens the reader without playing', (
    tester,
  ) async {
    await pump(
      tester,
      recordings: (_) => const [LibraryRecording(id: 'rec-1')],
    );

    await tester.tap(find.text('Praise to Tara'));
    await tester.pumpAndSettle();

    expect((opened.last as NavigationContext).autoPlay, isFalse);
  });
}

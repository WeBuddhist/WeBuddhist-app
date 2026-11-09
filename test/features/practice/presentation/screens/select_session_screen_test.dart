import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/practice/data/models/session_selection.dart';
import 'package:flutter_pecha/features/practice/domain/entities/practice_items_tab.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_items_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/select_session_screen.dart';
import 'package:flutter_pecha/features/recitation/data/models/my_recitation_list_collection_model.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_notifier.dart';
import 'package:flutter_pecha/features/timer/domain/entities/ambient_sound.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/providers/timers_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Right;
import 'package:flutter_test/flutter_test.dart';

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _IdlePracticeItems extends StateNotifier<PracticeItemsState>
    implements PracticeItemsNotifier {
  _IdlePracticeItems() : super(const PracticeItemsState(hasMore: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedRecitations extends StateNotifier<PracticeRecitationsState>
    implements PracticeRecitationsNotifier {
  _FixedRecitations(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _collection = MyRecitationListCollectionModel(
  type: 'RECITATION_COLLECTION',
  name: 'Morning prayers',
  collectionId: 'collection-1',
  itemCount: 3,
);

PracticeRecitationsState _collectionAndChant() => PracticeRecitationsState(
  collections: const [_collection],
  recitations: [RecitationModel(textId: 'text-1', title: 'Heart Sutra')],
  hasMore: false,
);

Future<Future<SessionSelection?>> _openChantsTab(
  WidgetTester tester,
  PracticeRecitationsState state,
) => _openPicker(tester, tab: 'Chants', chants: state);

/// Opens the picker on [tab] and returns what it pops with.
Future<Future<SessionSelection?>> _openPicker(
  WidgetTester tester, {
  required String tab,
  PracticeRecitationsState chants = const PracticeRecitationsState(
    hasMore: false,
  ),
  List<PresetTimer> timers = const [],
  List<AmbientSound> sounds = const [],
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
        practiceItemsPaginatedProvider(
          PracticeItemsTab.all,
        ).overrideWith((ref) => _IdlePracticeItems()),
        practiceRecitationsPaginatedProvider(
          'en',
        ).overrideWith((ref) => _FixedRecitations(chants)),
        presetTimersFutureProvider.overrideWith(
          () => ScreenCacheNotifier((ref, bind) => Right(timers)),
        ),
        ambientSoundsFutureProvider.overrideWith((ref) async => sounds),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(),
      ),
    ),
  );

  final selection = navigatorKey.currentState!.push<SessionSelection>(
    MaterialPageRoute(builder: (_) => const SelectSessionScreen()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
  return selection;
}

const _seaWaves = AmbientSound(id: 'sound-sea', name: 'Sea waves', url: '');
const _rain = AmbientSound(id: 'sound-rain', name: 'Rain', url: '');

const _morningTimer = PresetTimer(
  id: 'custom-1',
  name: '10 minutes',
  durationMs: 10 * 60000,
  type: kPresetTimerTypeUserCreated,
  description: 'Morning meditation',
  ambientSoundId: 'sound-sea',
);
const _tenMinutePreset = PresetTimer(
  id: 'preset-10',
  name: '10 minutes',
  durationMs: 10 * 60000,
  ambientSoundId: 'sound-rain',
);
const _fiveMinutePreset = PresetTimer(
  id: 'preset-5',
  name: '5 minutes',
  durationMs: 5 * 60000,
);

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  testWidgets('lists the user\'s collections above the chants', (tester) async {
    await _openChantsTab(tester, _collectionAndChant());

    final collectionTop = tester.getTopLeft(find.text('Morning prayers')).dy;
    final chantTop = tester.getTopLeft(find.text('Heart Sutra')).dy;
    expect(collectionTop, lessThan(chantTop));
  });

  testWidgets('tapping a collection pops it as the selection', (tester) async {
    final selection = await _openChantsTab(tester, _collectionAndChant());

    await tester.tap(find.text('Morning prayers'));
    await tester.pumpAndSettle();

    final result = await selection;
    expect(result, isA<MyRecitationCollectionSessionSelection>());
    expect(
      (result! as MyRecitationCollectionSessionSelection)
          .collection
          .collectionId,
      'collection-1',
    );
  });

  testWidgets('tapping a chant after the collections pops that chant', (
    tester,
  ) async {
    final selection = await _openChantsTab(tester, _collectionAndChant());

    await tester.tap(find.text('Heart Sutra'));
    await tester.pumpAndSettle();

    final result = await selection;
    expect(result, isA<RecitationSessionSelection>());
    expect((result! as RecitationSessionSelection).recitation.textId, 'text-1');
  });

  testWidgets('collections show even when there are no chants', (tester) async {
    await _openChantsTab(
      tester,
      const PracticeRecitationsState(
        collections: [_collection],
        hasMore: false,
      ),
    );

    expect(find.text('Morning prayers'), findsOneWidget);
    expect(find.text('No chants found'), findsNothing);
  });

  testWidgets('shows the empty message with no collections or chants', (
    tester,
  ) async {
    await _openChantsTab(
      tester,
      const PracticeRecitationsState(hasMore: false),
    );

    expect(find.text('No chants found'), findsOneWidget);
  });

  group('Timers tab', () {
    testWidgets('lists your timers, then presets shortest first', (
      tester,
    ) async {
      await _openPicker(
        tester,
        tab: 'Timer',
        timers: const [_tenMinutePreset, _morningTimer, _fiveMinutePreset],
        sounds: const [_seaWaves, _rain],
      );

      final yourTimers = find.text('YOUR TIMERS');
      final presets = find.text('PRESET TIMERS');
      final morning = find.text('Morning meditation');
      expect(yourTimers, findsOneWidget);
      expect(presets, findsOneWidget);
      expect(morning, findsOneWidget);

      expect(_top(tester, yourTimers), lessThan(_top(tester, morning)));
      expect(_top(tester, morning), lessThan(_top(tester, presets)));
      final fiveMin = find.text('5 min', findRichText: true);
      final tenMin = find.text('10 min', findRichText: true);
      expect(tenMin, findsNWidgets(2));
      // The custom 10 min timer sits above the header, the preset below
      // the 5 min one.
      expect(_top(tester, presets), lessThan(_top(tester, fiveMin)));
      expect(_top(tester, fiveMin), lessThan(_top(tester, tenMin.last)));

      expect(find.text('Sea waves'), findsOneWidget);
      expect(find.text('Rain'), findsOneWidget);
      expect(find.text('Default (no sound)'), findsOneWidget);
    });

    testWidgets('hides "Your timers" when the user has none', (tester) async {
      await _openPicker(
        tester,
        tab: 'Timer',
        timers: const [_fiveMinutePreset],
      );

      expect(find.text('YOUR TIMERS'), findsNothing);
      expect(find.text('PRESET TIMERS'), findsOneWidget);
    });

    testWidgets('tapping your timer pops it as the selection', (tester) async {
      final selection = await _openPicker(
        tester,
        tab: 'Timer',
        timers: const [_morningTimer, _fiveMinutePreset],
        sounds: const [_seaWaves],
      );

      await tester.tap(find.text('Morning meditation'));
      await tester.pumpAndSettle();

      final result = await selection;
      expect(result, isA<TimerSessionSelection>());
      expect((result! as TimerSessionSelection).timer.id, 'custom-1');
    });

    testWidgets('shows the empty message with no timers', (tester) async {
      await _openPicker(tester, tab: 'Timer');

      expect(find.text('No timers found'), findsOneWidget);
    });
  });
}

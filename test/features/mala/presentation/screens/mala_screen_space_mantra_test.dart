import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_pecha/features/group_profile/domain/repositories/group_accumulator_repository.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_accumulator_providers.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_local_datasource.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/domain/usecases/mala_usecases.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_sync_manager.dart';
import 'package:flutter_pecha/features/mala/presentation/screens/mala_screen.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_beads.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_notifier.dart';
import 'package:flutter_pecha/features/mala/data/models/accumulator_model.dart';
import 'package:flutter_pecha/features/mala/data/repositories/mala_repository_impl.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/space_mantra_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mantra_switcher.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/bookmark_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/recording_analytics_service.dart';
import '../../mala_fakes.dart';

const _userId = 'user-1';
const _accumulationId = 'acc-1';

const _mantra = MantraText(
  id: 'space-mantra',
  text: 'ཨོཾ་ཨཀྵོ་བྷྱ་ཧཱུྃ།',
  title: 'Akshobhya',
  pronunciation: 'Om Akshobhya Hum',
);

const _accumulation = GroupAccumulator(
  id: _accumulationId,
  presetAccumulatorId: '',
  mantraId: 'space-mantra',
  mantra: _mantra,
  groupId: 'space-1',
  title: 'Space Akshobhya',
  isJoined: true,
);

/// The backend: keeps the user's group count and, like the real server,
/// ignores a `current_count` lower than what it already has.
class _Server {
  _Server(this.total);

  int total;
  bool online = true;
  final sent = <int>[];
}

class _Repository extends Fake implements GroupAccumulatorRepositoryInterface {
  _Repository(this.server);

  final _Server server;

  @override
  Future<Either<Failure, GroupAccumulatorDetail>> refreshGroupAccumulator(
    String accumulatorId, {
    required String language,
  }) async {
    if (!server.online) return const Left(NetworkFailure('offline'));
    return Right(
      GroupAccumulatorDetail(
        id: accumulatorId,
        presetAccumulatorId: '',
        groupId: 'space-1',
        title: 'Space Akshobhya',
        user: GroupAccumulatorUserContribution(totalCount: server.total),
      ),
    );
  }
}

class _Submit extends Fake implements SubmitGroupAccumulatorCountUseCase {
  _Submit(this.server);

  final _Server server;

  @override
  Future<Either<Failure, Unit>> call(
    SubmitGroupAccumulatorCountParams params,
  ) async {
    if (!server.online) return const Left(NetworkFailure('offline'));
    server.sent.add(params.currentCount);
    server.total = max(server.total, params.currentCount);
    return const Right(unit);
  }
}

class _UnusedCreate extends Fake implements CreateUserAccumulatorUseCase {}

class _UnusedUpdate extends Fake implements UpdateUserAccumulatorUseCase {}

/// In-memory stand-in for the Hive-backed group counts.
class _Local extends Fake implements MalaLocalDataSource {
  final groups = <String, LocalGroupMalaState>{};

  @override
  LocalMalaState read(String userId, String presetId) => const LocalMalaState();

  @override
  List<String> dirtyPresetIds(String userId) => const [];

  @override
  LocalGroupMalaState readGroup(String userId, String groupAccumulatorId) =>
      groups[groupAccumulatorId] ?? const LocalGroupMalaState();

  @override
  Future<void> writeGroup(
    String userId,
    String groupAccumulatorId,
    LocalGroupMalaState s,
  ) async => groups[groupAccumulatorId] = s;

  @override
  Future<LocalGroupMalaState> recordGroupTap(
    String userId,
    String groupAccumulatorId,
  ) async {
    final s = readGroup(userId, groupAccumulatorId);
    return groups[groupAccumulatorId] = s.copyWith(total: s.total + 1);
  }

  @override
  List<String> groupAccumulatorIdsForUser(String userId) =>
      groups.keys.toList();

  @override
  List<String> dirtyGroupAccumulatorIds(String userId) => [
    for (final e in groups.entries)
      if (e.value.isDirty) e.key,
  ];
}

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness({int serverTotal = 0}) : server = _Server(serverTotal) {
    sync = MalaSyncManager(
      local: local,
      createAccumulator: _UnusedCreate(),
      updateAccumulator: _UnusedUpdate(),
      submitGroupCount: _Submit(server),
      isLoggedIn: () => true,
      currentUserId: () async => _userId,
    );
  }

  final _Server server;
  final local = _Local();
  late final MalaSyncManager sync;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            FakeUserStorage(_userId),
          ),
          malaLocalDataSourceProvider.overrideWithValue(local),
          malaRemoteDataSourceProvider.overrideWithValue(FakeMalaRemote()),
          malaSyncManagerProvider.overrideWithValue(sync),
          malaSoundPlayerProvider.overrideWithValue(SilentMalaSoundPlayer()),
          analyticsServiceProvider.overrideWithValue(
            RecordingAnalyticsService(),
          ),
          contentLanguageProvider.overrideWith(
            (ref) => _FixedContentLanguage(),
          ),
          groupAccumulatorRepositoryProvider.overrideWithValue(
            _Repository(server),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MalaScreen(singleAccumulation: _accumulation),
        ),
      ),
    );
    await settle(tester);
  }

  /// The marquee animates forever, so settle with a few fixed pumps.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  MalaBeads beads(WidgetTester tester) =>
      tester.widget<MalaBeads>(find.byType(MalaBeads));

  Future<void> chant(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      beads(tester).onTap();
      await tester.pump();
    }
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    // Let an offline preset counter's seed timeout run out.
    await tester.pump(const Duration(seconds: 4));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('main mala carousel', carouselTests);

  testWidgets('a new device starts from the server count, not 0', (
    tester,
  ) async {
    final h = _Harness(serverTotal: 500);
    await h.pump(tester);

    expect(h.beads(tester).total, 500);
    expect(h.beads(tester).enabled, isTrue);

    await h.chant(tester, 3);
    expect(h.beads(tester).total, 503);

    await h.leave(tester);
    expect(h.server.total, 503);
    expect(h.server.sent, isNot(contains(lessThan(500))));
  });

  testWidgets(
    'lost-chants bug: when the count fails to load, chanting is blocked '
    'and a retry is shown',
    (tester) async {
      final h = _Harness(serverTotal: 500)..server.online = false;
      await h.pump(tester);

      expect(find.byType(MalaBeads), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(h.local.groups, isEmpty, reason: 'nothing may be counted');

      // Back online: retry loads the real total and chanting resumes on it.
      h.server.online = true;
      await tester.tap(find.text('Retry'));
      await h.settle(tester);

      expect(h.beads(tester).total, 500);
      expect(h.beads(tester).enabled, isTrue);
      await h.chant(tester, 2);
      await h.leave(tester);

      expect(h.server.total, 502);
      expect(h.server.sent, everyElement(greaterThanOrEqualTo(500)));
    },
  );

  testWidgets('chants made offline sync once the connection is back', (
    tester,
  ) async {
    final h = _Harness(serverTotal: 100);
    await h.pump(tester);

    h.server.online = false;
    await h.chant(tester, 5);
    expect(h.beads(tester).total, 105);
    expect(h.local.groups[_accumulationId]!.isDirty, isTrue);
    expect(h.server.total, 100);

    h.server.online = true;
    await h.sync.flush(SyncReason.reconnect);
    expect(h.server.total, 105);
    expect(h.local.groups[_accumulationId]!.isDirty, isFalse);
    await h.leave(tester);
  });

  testWidgets('leaving the screen right after chanting still syncs', (
    tester,
  ) async {
    final h = _Harness(serverTotal: 10);
    await h.pump(tester);

    // Fewer than a round: only the 5s debounce or the leave flush sends it.
    h.beads(tester).onTap();
    await tester.pump();
    await h.leave(tester);

    expect(h.server.total, 11);
  });

  testWidgets('settings sheet has only speed, sound and vibration', (
    tester,
  ) async {
    final h = _Harness(serverTotal: 0);
    await h.pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await h.settle(tester);

    expect(find.text('Mantra speed'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.textContaining('Bookmark'), findsNothing);
    expect(find.textContaining('Share'), findsNothing);
    await h.leave(tester);
  });

  testWidgets('a single mantra hides the switcher arrows', (tester) async {
    final h = _Harness(serverTotal: 0);
    await h.pump(tester);

    for (final icon in [AppAssets.caretLeft2, AppAssets.caretRight2]) {
      final arrow = tester.widget<Visibility>(
        find
            .ancestor(of: find.byIcon(icon), matching: find.byType(Visibility))
            .first,
      );
      expect(arrow.visible, isFalse);
    }
    await h.leave(tester);
  });

  testWidgets('a bead image that fails to load falls back to the drawn bead', (
    tester,
  ) async {
    final h = _Harness(serverTotal: 0);
    await h.pump(tester);

    expect(h.beads(tester).beadImageBytes, isNull);
    expect(tester.takeException(), isNull);
    await h.leave(tester);
  });
}

// ---------------------------------------------------------------------------
// Main mala carousel: joined space mantras listed after the public presets.
// ---------------------------------------------------------------------------

class _OfflineRemote extends FakeMalaRemote {
  /// Offline: a preset's personal counter falls back to its local total.
  @override
  Future<AccumulatorDetailModel?> fetchAccumulatorDetail(String parentId) =>
      throw Exception('offline');

  @override
  Future<Map<String, dynamic>> fetchAccumulatorGroupsJson(
    String accumulatorId, {
    bool joinedOnly = false,
    String? language,
  }) async => {'groups': const [], 'total': 0, 'skip': 0, 'limit': 20};
}

const _tara = Mantra(
  presetId: 'tara',
  metadata: [AccumulatorMetadata(language: 'en', name: 'Tara')],
  mantra: MantraText(id: 'tara-mantra', text: 'ཨོཾ་ཏཱ་རེ།', title: 'Tara'),
);

const _otherMantra = MantraText(
  id: 'other-mantra',
  text: 'ཨོཾ་མ་ཎི།',
  title: 'Space Mani',
);

Future<_Harness> _pumpCarousel(
  WidgetTester tester,
  List<GroupAccumulator> joined,
) async {
  final h = _Harness(serverTotal: 42);
  final remote = _OfflineRemote();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(FakeUserStorage(_userId)),
        malaLocalDataSourceProvider.overrideWithValue(h.local),
        malaRemoteDataSourceProvider.overrideWithValue(remote),
        malaRepositoryProvider.overrideWithValue(
          MalaRepositoryImpl(remote: remote),
        ),
        malaSyncManagerProvider.overrideWithValue(h.sync),
        malaSoundPlayerProvider.overrideWithValue(SilentMalaSoundPlayer()),
        analyticsServiceProvider.overrideWithValue(RecordingAnalyticsService()),
        contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
        groupAccumulatorRepositoryProvider.overrideWithValue(
          _Repository(h.server),
        ),
        prefetchBookmarkExistsProvider.overrideWith((ref, target) {}),
        malaCatalogueProvider.overrideWith(
          () => ScreenCacheNotifier.fixed(const Right([_tara])),
        ),
        joinedSpaceMantrasProvider.overrideWith(
          (ref) async => [
            for (final a in joined)
              if (SpaceMantraItem.from(a) case final item?) item,
          ],
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MalaScreen(),
      ),
    ),
  );
  await h.settle(tester);
  return h;
}

void _goTo(WidgetTester tester, int index) {
  tester
      .widget<MantraSwitcher>(find.byType(MantraSwitcher))
      .onIndexChanged(index);
}

void carouselTests() {
  testWidgets('a joined space mantra is listed after the presets', (
    tester,
  ) async {
    final h = await _pumpCarousel(tester, [_accumulation]);

    final switcher = tester.widget<MantraSwitcher>(find.byType(MantraSwitcher));
    expect(switcher.mantras.map((m) => m.presetId), [
      'tara',
      'group:$_accumulationId',
    ]);
    expect(switcher.index, 0, reason: 'opens on the first preset');
    await h.leave(tester);
  });

  testWidgets('a space accumulation using its preset mantra is not repeated', (
    tester,
  ) async {
    const viaPreset = GroupAccumulator(
      id: 'acc-tara',
      presetAccumulatorId: 'tara',
      mantra: MantraText(id: 'tara-mantra', text: 'ཨོཾ་ཏཱ་རེ།'),
      groupId: 'space-1',
      title: 'Space Tara',
      isJoined: true,
    );
    const ownMantraOnPreset = GroupAccumulator(
      id: 'acc-own',
      presetAccumulatorId: 'tara',
      mantra: _otherMantra,
      groupId: 'space-1',
      title: 'Space Mani',
      isJoined: true,
    );
    final h = await _pumpCarousel(tester, [viaPreset, ownMantraOnPreset]);

    final switcher = tester.widget<MantraSwitcher>(find.byType(MantraSwitcher));
    expect(switcher.mantras.map((m) => m.presetId), ['tara', 'group:acc-own']);
    await h.leave(tester);
  });

  testWidgets('swiping to a space mantra shows and counts its own total', (
    tester,
  ) async {
    final h = await _pumpCarousel(tester, [_accumulation]);

    _goTo(tester, 1);
    await h.settle(tester);
    expect(find.text('Akshobhya'), findsWidgets);
    expect(h.beads(tester).total, 42, reason: 'the server count of acc-1');

    await h.chant(tester, 2);
    expect(h.beads(tester).total, 44);

    // Settings for a space mantra: no bookmark/share/add-to-practice.
    await tester.tap(find.byIcon(Icons.more_vert));
    await h.settle(tester);
    expect(find.text('Mantra speed'), findsOneWidget);
    expect(find.textContaining('Bookmark'), findsNothing);
    Navigator.of(tester.element(find.text('Mantra speed'))).pop();
    await h.settle(tester);

    // Back to the preset and again to the space mantra: the count is kept.
    _goTo(tester, 0);
    await h.settle(tester);
    _goTo(tester, 1);
    await h.settle(tester);
    expect(h.beads(tester).total, 44);

    await h.leave(tester);
    expect(h.server.total, 44);
  });
}

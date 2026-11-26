import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/network/connectivity_service.dart';
import 'package:flutter_pecha/core/services/share_url/share_url_service.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_local_datasource.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_count.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/domain/repositories/mala_repository.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/screens/mala_settings_screen.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_image_option.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/bookmark_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/recording_analytics_service.dart';
import '../../mala_fakes.dart';

/// share_plus forwards every share to this channel; holding its reply lets
/// the test check the page while the share is still in flight.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

const _shortUrl = 'https://short.example/mala-1';
const _shareMessage =
    "I've been using this digital mala on WeBuddhist and wanted to share it "
    "with you. It's an easy way to practice wherever you go.";

const _mantra = Mantra(
  presetId: 'tara-praises',
  mantra: MantraText(id: 'tara-mantra', text: 'om'),
);

class _FakeShareUrlService implements ShareUrlService {
  @override
  Future<String> shorten(String longUrl) async => _shortUrl;
}

class _FakeLocal extends Fake implements MalaLocalDataSource {
  @override
  LocalMalaState read(String userId, String presetId) => const LocalMalaState();

  @override
  LocalGroupMalaState readGroup(String userId, String groupAccumulatorId) =>
      const LocalGroupMalaState();

  @override
  List<String> groupAccumulatorIdsForUser(String userId) => const [];
}

/// Offline: the counter seeds from its local total without the network.
class _OfflineRepository extends Fake implements MalaRepository {
  @override
  Future<Either<Failure, MalaCount>> getAccumulatorDetail(
    String parentId,
  ) async => const Left(NetworkFailure('offline'));
}

class _OnlineNotifier extends ConnectivityNotifier {
  @override
  bool build() => true;
}

/// Two images and two skins with empty URLs, so nothing loads from the
/// network in tests.
FakeMalaAppearanceRepository _appearanceServer({
  String? deityImageId,
  String? malaSkinId,
}) => FakeMalaAppearanceRepository(
  deityOptions: const [
    MalaImageOption(
      id: 'own',
      image: ResponsiveImage(thumbnail: ''),
      isDefault: true,
    ),
    MalaImageOption(id: 'other', image: ResponsiveImage(thumbnail: '')),
  ],
  skinList: const [
    MalaSkin(id: 'skin-ellipse', name: 'ellipse', url: '', isDefault: true),
    MalaSkin(id: 'skin-bodhi', name: 'bodhi_seed', url: ''),
  ],
  deityImageId: deityImageId,
  malaSkinId: malaSkinId,
);

class _Host {
  _Host({FakeMalaAppearanceRepository? server, this.mantra = _mantra})
    : server = server ?? _appearanceServer();

  final service = RecordingAnalyticsService();
  final FakeMalaAppearanceRepository server;
  final Mantra mantra;

  /// What settings closed with; null while open (or closed with nothing).
  MalaSettingsOutcome? outcome;
  bool closed = false;

  Future<void> open(WidgetTester tester) async {
    // Tall enough to show every settings row.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext hostContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shareUrlServiceProvider.overrideWithValue(_FakeShareUrlService()),
          analyticsServiceProvider.overrideWithValue(service),
          isBookmarkedProvider.overrideWith((ref, target) => false),
          connectivityNotifierProvider.overrideWith(_OnlineNotifier.new),
          localStorageServiceProvider.overrideWithValue(
            FakeUserStorage('user-1'),
          ),
          malaLocalDataSourceProvider.overrideWithValue(_FakeLocal()),
          malaRepositoryProvider.overrideWithValue(_OfflineRepository()),
          malaRemoteDataSourceProvider.overrideWithValue(FakeMalaRemote()),
          malaSyncManagerProvider.overrideWithValue(FakeMalaSync()),
          malaSoundPlayerProvider.overrideWithValue(SilentMalaSoundPlayer()),
          malaAppearanceRepositoryProvider.overrideWithValue(server),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );

    MalaSettingsScreen.show(hostContext, mantra: mantra).then((value) {
      outcome = value;
      closed = true;
    });
    await tester.pumpAndSettle();
    // Lets the counter's seed timeout run out so no timer is left pending.
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MalaSettingsScreen), findsOneWidget);
  }
}

/// Opens Mala settings and taps Share; the share reply is held in
/// [shareResult].
Future<RecordingAnalyticsService> _tapShare(
  WidgetTester tester, {
  required Completer<String> shareResult,
  required List<MethodCall> shareCalls,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_shareChannel, (call) {
        shareCalls.add(call);
        return shareResult.future;
      });
  final host = _Host();
  await host.open(tester);

  // The page is taller than the test viewport.
  await tester.ensureVisible(find.text('Share'));
  await tester.tap(find.text('Share'));
  await tester.pumpAndSettle();

  // Settings stay open while the share sheet is up.
  expect(find.byType(MalaSettingsScreen), findsOneWidget);
  expect(shareCalls, hasLength(1));
  expect(host.service.events, isEmpty);
  return host.service;
}

void main() {
  final shareCalls = <MethodCall>[];

  setUp(() {
    shareCalls.clear();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
  });

  testWidgets('shows the practice, appearance and save sections', (
    tester,
  ) async {
    await _Host().open(tester);

    for (final label in [
      'Add to my practices',
      'Practice',
      'Mantra animation',
      'Sound',
      'Vibration',
      'Reset count',
      'Appearance',
      'Bead style',
      'Change image',
      'Save & share',
      'Bookmark',
      'Share',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // The bead style row shows the mantra's own bead by default.
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('shares the mala message with its short link', (tester) async {
    final shareResult = Completer<String>();
    await _tapShare(tester, shareResult: shareResult, shareCalls: shareCalls);
    shareResult.complete('dev.fluttercommunity.plus/share/success');
    await tester.pump();

    final args = shareCalls.single.arguments as Map<Object?, Object?>;
    expect(args['text'], '$_shareMessage\n\n$_shortUrl');
  });

  testWidgets('records one content_shared once the share completes', (
    tester,
  ) async {
    final shareResult = Completer<String>();
    final service = await _tapShare(
      tester,
      shareResult: shareResult,
      shareCalls: shareCalls,
    );

    shareResult.complete('dev.fluttercommunity.plus/share/success');
    await tester.pump();

    expect(service.eventNames, [AnalyticsEvents.contentShared]);
    expect(service.events.single.properties, {
      'surface': 'mala',
      'target_id': 'tara-praises',
      'language': 'en',
      'format': 'text',
      'method': null,
      'group_id': null,
    });
  });

  testWidgets('records nothing when the share sheet is dismissed', (
    tester,
  ) async {
    final shareResult = Completer<String>();
    final service = await _tapShare(
      tester,
      shareResult: shareResult,
      shareCalls: shareCalls,
    );

    // share_plus reports a dismissed sheet as an empty result.
    shareResult.complete('');
    await tester.pump();

    expect(service.events, isEmpty);
  });

  testWidgets('turning play animation off shows Off in settings', (
    tester,
  ) async {
    await _Host().open(tester);
    expect(find.text('1x'), findsOneWidget);

    await tester.tap(find.text('Mantra animation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play animation'));
    // The toggle sits on the same row as the label.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Play animation'),
          matching: find.byType(Row),
        ),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'AppToggleSwitch',
        ),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Play animation'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('mala_play_animation'), isFalse);
  });

  testWidgets('hides appearance for a mantra without an id', (tester) async {
    await _Host(mantra: const Mantra(presetId: 'tara-praises')).open(tester);

    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Bead style'), findsNothing);
    expect(find.text('Change image'), findsNothing);
    expect(find.text('Sound'), findsOneWidget);
  });

  testWidgets('the bead style row names the picked skin', (tester) async {
    await _Host(
      server: _appearanceServer(malaSkinId: 'skin-bodhi'),
    ).open(tester);

    expect(find.text('Bodhi seed'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
  });

  testWidgets('using a bead skin saves it and closes settings', (tester) async {
    final host = _Host();
    await host.open(tester);

    await tester.tap(find.text('Bead style'));
    await tester.pumpAndSettle();
    // Default plus the server's skins, named for display.
    expect(find.bySemanticsLabel('Default'), findsOneWidget);
    expect(find.bySemanticsLabel('Ellipse'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Bodhi seed'));
    await tester.pump();
    await tester.tap(find.text('Use this style'));
    await tester.pumpAndSettle();

    expect(host.server.patches, [
      {'mala_skin_id': 'skin-bodhi'},
    ]);
    expect(host.closed, isTrue);
    expect(host.outcome, MalaSettingsOutcome.beadStyleUpdated);
    expect(find.byType(MalaSettingsScreen), findsNothing);
  });

  testWidgets('choosing Default clears the bead skin', (tester) async {
    final host = _Host(server: _appearanceServer(malaSkinId: 'skin-bodhi'));
    await host.open(tester);

    await tester.tap(find.text('Bead style'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Default'));
    await tester.pump();
    await tester.tap(find.text('Use this style'));
    await tester.pumpAndSettle();

    expect(host.server.patches, [
      {'mala_skin_id': null},
    ]);
    expect(host.outcome, MalaSettingsOutcome.beadStyleUpdated);
  });

  testWidgets('keeping the same bead skin saves nothing', (tester) async {
    final host = _Host();
    await host.open(tester);

    await tester.tap(find.text('Bead style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this style'));
    await tester.pumpAndSettle();

    expect(host.server.patches, isEmpty);
    expect(find.byType(MalaSettingsScreen), findsOneWidget);
  });

  testWidgets('a failed bead save shows an error and keeps the sheet', (
    tester,
  ) async {
    final host = _Host()..server.failSaves = true;
    await host.open(tester);

    await tester.tap(find.text('Bead style'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Bodhi seed'));
    await tester.pump();
    await tester.tap(find.text('Use this style'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't save. Please try again"), findsOneWidget);
    expect(find.text('Use this style'), findsOneWidget);
    expect(host.closed, isFalse);
    // Let the toast time out.
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('using another image saves it; restore default clears it', (
    tester,
  ) async {
    final server = _appearanceServer();
    final host = _Host(server: server);
    await host.open(tester);

    await tester.tap(find.text('Change image'));
    await tester.pumpAndSettle();
    final restore = find.widgetWithText(TextButton, 'Restore default');
    expect(tester.widget<TextButton>(restore).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('mala-image-other')));
    await tester.pump();
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(server.patches, [
      {'deity_image_id': 'other'},
    ]);
    expect(host.closed, isTrue);
    expect(host.outcome, MalaSettingsOutcome.imageUpdated);

    // Reopen: restore default is now enabled and clears the pick.
    final again = _Host(server: server);
    await again.open(tester);
    await tester.tap(find.text('Change image'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(server.patches.last, {'deity_image_id': null});
    expect(again.outcome, MalaSettingsOutcome.imageUpdated);
  });

  testWidgets('picking the default image saves no pick', (tester) async {
    final server = _appearanceServer(deityImageId: 'other');
    final host = _Host(server: server);
    await host.open(tester);

    await tester.tap(find.text('Change image'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mala-image-own')));
    await tester.pump();
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(server.patches, [
      {'deity_image_id': null},
    ]);
  });
}

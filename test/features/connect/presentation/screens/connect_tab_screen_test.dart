import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_space_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/screens/connect_tab_screen.dart';
import 'package:flutter_pecha/features/group_profile/data/datasource/group_profile_remote_datasource.dart';
import 'package:flutter_pecha/features/group_profile/data/repositories/group_profile_repository_impl.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/screens/group_profile_screen.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_profile_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_screen_cache_store.dart';

class _SignedInAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedInAuth() : super(const AuthState(isLoggedIn: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Never answers, so the space page stays on its skeleton: these tests are
/// about how the Connect tab opens a space, not what the space shows.
class _PendingRemote extends GroupProfileRemoteDatasource {
  _PendingRemote() : super(dio: Dio());

  @override
  Future<Map<String, dynamic>> fetchGroupProfileJson(
    String groupId, {
    required String language,
  }) => Completer<Map<String, dynamic>>().future;
}

const _spaces = [
  GroupProfile(id: 'a', title: 'WeBuddhist'),
  GroupProfile(id: 'b', title: 'Light of Buddhadharma'),
];

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required List<String> opened,
    String lastSpaceId = 'a',
  }) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.connectLastSpaceId: lastSpaceId,
      StorageKeys.connectOpenedSpaceIds: opened,
    });
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
        analyticsServiceProvider.overrideWithValue(_NoopAnalytics()),
        joinedSpacesProvider.overrideWithValue(
          const JoinedSpaces(spaces: _spaces, isLoading: false),
        ),
        unreadSpacesProvider.overrideWithValue(const {}),
        groupProfileRepositoryProvider.overrideWithValue(
          GroupProfileRepositoryImpl(
            remote: _PendingRemote(),
            store: FakeScreenCacheStore(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConnectTabScreen()),
        ),
      ),
    );
    await settle(tester);
    return container;
  }

  void expectSpace(WidgetTester tester, String id, {required bool onFeed}) {
    final screen = tester.widget<GroupProfileScreen>(
      find.byType(GroupProfileScreen),
    );
    expect(screen.groupId, id);
    expect(screen.startCollapsed, onFeed);
  }

  Future<Set<String>> storedOpened() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(StorageKeys.connectOpenedSpaceIds)};
  }

  Future<void> switchTo(
    WidgetTester tester,
    ProviderContainer container,
    String id,
  ) async {
    await container.read(connectLastSpaceProvider.notifier).select(id);
    await settle(tester);
  }

  testWidgets('first visit opens on the space info and is remembered', (
    tester,
  ) async {
    final container = await pump(tester, opened: const []);

    expectSpace(tester, 'a', onFeed: false);
    expect(container.read(connectOpenedSpacesProvider).ids, {'a'});
    expect(await storedOpened(), {'a'});
    await unmount(tester);
  });

  testWidgets('recording the first visit does not collapse it', (tester) async {
    await pump(tester, opened: const []);
    // More frames after the space was recorded as opened.
    await settle(tester);

    expectSpace(tester, 'a', onFeed: false);
    await unmount(tester);
  });

  testWidgets('a space opened before opens on the feed', (tester) async {
    await pump(tester, opened: const ['a']);

    expectSpace(tester, 'a', onFeed: true);
    await unmount(tester);
  });

  testWidgets('each space follows its own first visit', (tester) async {
    final container = await pump(tester, opened: const ['a']);
    expectSpace(tester, 'a', onFeed: true);

    // First time in b: its info.
    await switchTo(tester, container, 'b');
    expectSpace(tester, 'b', onFeed: false);
    expect(await storedOpened(), {'a', 'b'});

    // Back to a, then b again: both on the feed now.
    await switchTo(tester, container, 'a');
    expectSpace(tester, 'a', onFeed: true);
    await switchTo(tester, container, 'b');
    expectSpace(tester, 'b', onFeed: true);
    await unmount(tester);
  });

  testWidgets('waits for the opened spaces before opening one', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        joinedSpacesProvider.overrideWithValue(
          const JoinedSpaces(spaces: _spaces, isLoading: false),
        ),
        // The last space is already known, so only the opened list is read.
        connectLastSpaceProvider.overrideWith((ref) => _KnownLastSpace('a')),
        connectOpenedSpacesProvider.overrideWith(
          (ref) => _NeverLoadedOpenedSpaces(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ConnectTabScreen())),
      ),
    );

    await tester.pump();

    // Opening now could land a returning visit on the info by mistake.
    expect(find.byType(GroupProfileSkeleton), findsOneWidget);
    expect(find.byType(GroupProfileScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

/// The stored opened ids, still being read.
class _NeverLoadedOpenedSpaces extends StateNotifier<ConnectOpenedSpaces>
    implements ConnectOpenedSpacesNotifier {
  _NeverLoadedOpenedSpaces() : super(const ConnectOpenedSpaces());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _KnownLastSpace extends ConnectLastSpaceNotifier {
  _KnownLastSpace(String id) {
    state = ConnectLastSpace(spaceId: id, loaded: true);
  }
}

/// A few frames: the stored ids load, then the post-frame recording runs.
/// Not pumpAndSettle, since the space skeleton shimmers forever.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_source.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/connect/domain/entities/discover_groups_page.dart';
import 'package:flutter_pecha/features/connect/domain/entities/space_sort.dart';
import 'package:flutter_pecha/features/connect/domain/repositories/connect_repository.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/group_search_provider.dart';
import 'package:flutter_pecha/features/connect/presentation/screens/group_search_screen.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../helpers/fake_screen_cache_store.dart';

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiscoverGroupsPage _page(String prefix, {required int skip, int total = 40}) {
  return DiscoverGroupsPage(
    groups: [
      for (var i = skip; i < skip + 20; i++)
        GroupProfile(id: '$prefix$i', title: '$prefix $i'),
    ],
    skip: skip,
    limit: 20,
    total: total,
  );
}

/// Search pages come from [onSearch]; "Looking for" pages are `d0…` rows.
class _FakeConnectRepository extends Fake implements ConnectRepository {
  final searchSkips = <int>[];
  final discoverSkips = <int>[];
  Future<Either<Failure, DiscoverGroupsPage>> Function(int skip) onSearch =
      (skip) async => Right(_page('s', skip: skip));

  @override
  Future<Either<Failure, DiscoverGroupsPage>> getDiscoverGroups({
    required String language,
    int skip = 0,
    int limit = 20,
    String? search,
    SpaceSort? sort,
    bool includeJoined = false,
  }) {
    if (search != null) {
      searchSkips.add(skip);
      return onSearch(skip);
    }
    discoverSkips.add(skip);
    return Future.value(Right(_page('d', skip: skip, total: 100)));
  }

  @override
  ScreenCacheSource<DiscoverGroupsPage> discoverGroupsFirstPage({
    required String language,
    required int limit,
    required SpaceSort sort,
  }) {
    return ScreenCacheSource(
      store: FakeScreenCacheStore(),
      key: 'test:discover_groups',
      fetchJson: () async => <String, dynamic>{},
      fromJson: (_) => _page('d', skip: 0, total: 100),
      failureMessage: 'test',
    );
  }
}

void main() {
  late _FakeConnectRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeConnectRepository();
    container = ProviderContainer(
      overrides: [
        contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
        connectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  group('GroupSearchNotifier.loadMore', () {
    test('waits for the first page instead of fetching it twice', () async {
      final firstPage = Completer<Either<Failure, DiscoverGroupsPage>>();
      repository.onSearch =
          (skip) =>
              skip == 0
                  ? firstPage.future
                  : Future.value(Right(_page('s', skip: skip)));
      container.listen(groupSearchProvider, (_, __) {});
      final notifier = container.read(groupSearchProvider.notifier);

      notifier.search('a');
      await notifier.loadMore(); // still debouncing
      expect(repository.searchSkips, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 550));
      expect(repository.searchSkips, [0]);
      await notifier.loadMore(); // first page in flight
      expect(repository.searchSkips, [0]);

      firstPage.complete(Right(_page('s', skip: 0)));
      await pumpEventQueue();
      final ids = container.read(groupSearchProvider).results.map((g) => g.id);
      expect(ids.toSet().length, ids.length);
      expect(container.read(groupSearchProvider).skip, 20);

      await notifier.loadMore();
      expect(repository.searchSkips, [0, 20]);
    });

    test('a page for an older query is dropped', () async {
      final oldPage = Completer<Either<Failure, DiscoverGroupsPage>>();
      repository.onSearch = (_) => oldPage.future;
      container.listen(groupSearchProvider, (_, __) {});
      final notifier = container.read(groupSearchProvider.notifier);

      notifier.search('old');
      await Future<void>.delayed(const Duration(milliseconds: 550));
      repository.onSearch = (skip) async => Right(_page('new', skip: skip));
      notifier.search('new');
      await Future<void>.delayed(const Duration(milliseconds: 550));
      oldPage.complete(Right(_page('old', skip: 0)));
      await pumpEventQueue();

      final state = container.read(groupSearchProvider);
      expect(state.query, 'new');
      expect(state.results.every((g) => g.id.startsWith('new')), isTrue);
    });
  });

  group('GroupSearchScreen paging', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GroupSearchScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> typeQuery(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump();
    }

    testWidgets('scrolling during the first search fetches it once', (
      tester,
    ) async {
      final firstPage = Completer<Either<Failure, DiscoverGroupsPage>>();
      repository.onSearch =
          (skip) =>
              skip == 0
                  ? firstPage.future
                  : Future.value(Right(_page('s', skip: skip)));
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 550));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump();

      firstPage.complete(Right(_page('s', skip: 0)));
      await tester.pump();
      await tester.pump();

      // Page zero once; later pages are real paging from the bottom.
      expect(repository.searchSkips.where((skip) => skip == 0), hasLength(1));
      final ids =
          container.read(groupSearchProvider).results.map((g) => g.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(container.read(groupSearchProvider).skip, ids.length);
    });

    testWidgets('reaching the last result loads more results right away', (
      tester,
    ) async {
      await pumpScreen(tester);
      await typeQuery(tester, 'a');
      expect(repository.searchSkips, [0]);

      // Near the end of the results, well above the end of the page.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();
      await tester.pump();

      expect(repository.searchSkips, [0, 20]);
      expect(repository.discoverSkips, isNot(contains(20)));
    });

    testWidgets('a failed search still lets "Looking for" load more', (
      tester,
    ) async {
      repository.onSearch = (_) async => const Left(NetworkFailure('offline'));
      await pumpScreen(tester);
      await typeQuery(tester, 'a');
      expect(container.read(groupSearchProvider).hasMore, isTrue);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pump();

      expect(repository.discoverSkips, contains(20));
      expect(repository.searchSkips, [0]);
    });
  });
}

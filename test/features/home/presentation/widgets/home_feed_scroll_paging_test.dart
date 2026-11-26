import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_source.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/data/models/home_feed_model.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:flutter_pecha/features/home/domain/repositories/home_feed_repository.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_feed_provider.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/home_feed_sliver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../helpers/fake_screen_cache_store.dart';

Map<String, dynamic> _page(List<String> ids, {String? next}) => {
  'items': [
    for (final id in ids)
      {
        'type': 'post',
        'id': 'card-$id',
        'content': {
          'type': 'post',
          'space_id': 's',
          'post': {'id': id},
        },
      },
  ],
  'next_cursor': next,
};

class _Repository implements HomeFeedRepository {
  final afters = <HomeFeedPageToken?>[];

  @override
  Future<Either<Failure, HomeFeedPage>> getFeed({
    required bool signedIn,
    required String language,
    HomeFeedPageToken? after,
  }) async {
    afters.add(after);
    return Right(
      HomeFeedModel.parseMemberPage(_page(['n1']), language: 'en'),
    );
  }
}

void main() {
  testWidgets('scrolling Home to its end asks for the next page', (
    tester,
  ) async {
    final repository = _Repository();
    final firstPage = ScreenCacheSource<HomeFeedPage>(
      store: FakeScreenCacheStore(),
      key: 'k',
      fetchJson:
          () async => _page([for (var i = 0; i < 20; i++) 'p$i'], next: 'c1'),
      fromJson:
          (json) => HomeFeedModel.parseMemberPage(
            jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
            language: 'en',
          ),
      failureMessage: 'f',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeFeedProvider.overrideWith(
            (ref) => HomeFeedNotifier(
              repository: repository,
              firstPage: firstPage,
              signedIn: true,
              language: 'en',
            ),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(
                homeFeedProvider.select((s) => s.items.length),
              );
              // Shaped like Home: refresh, listener, one scroll view.
              return Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {},
                        child: NotificationListener<ScrollNotification>(
                          onNotification:
                              (n) => HomeFeedSliver.onScroll(ref, n),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 100),
                              ),
                              SliverList.builder(
                                itemCount: count,
                                itemBuilder:
                                    (_, i) => SizedBox(
                                      height: 300,
                                      child: Text('card $i'),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('card 0'), findsOneWidget);
    expect(repository.afters, isEmpty);

    for (var i = 0; i < 12 && repository.afters.isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
    }

    expect(repository.afters, [const HomeFeedCursor('c1')]);
  });

  testWidgets('pages on without a scroll while the end is still in reach', (
    tester,
  ) async {
    // Page two holds nothing Home shows; page three is the last.
    final repository = _ScriptedRepository([
      _page([], next: 'c2'),
      _page(['p1']),
    ]);
    final firstPage = ScreenCacheSource<HomeFeedPage>(
      store: FakeScreenCacheStore(),
      key: 'k',
      fetchJson: () async => _page(['p0'], next: 'c1'),
      fromJson:
          (json) => HomeFeedModel.parseMemberPage(
            jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
            language: 'en',
          ),
      failureMessage: 'f',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeFeedProvider.overrideWith(
            (ref) => HomeFeedNotifier(
              repository: repository,
              firstPage: firstPage,
              signedIn: true,
              language: 'en',
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                Consumer(
                  builder: (context, ref, _) {
                    final state = ref.watch(homeFeedProvider);
                    HomeFeedSliver.continuePaging(context, ref, state);
                    return SliverList.builder(
                      itemCount: state.items.length,
                      itemBuilder:
                          (_, i) => SizedBox(
                            height: 100,
                            child: Text('card $i'),
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.afters, [
      const HomeFeedCursor('c1'),
      const HomeFeedCursor('c2'),
    ]);
    expect(find.text('card 1'), findsOneWidget);
  });
}

class _ScriptedRepository implements HomeFeedRepository {
  _ScriptedRepository(this._pages);

  final List<Map<String, dynamic>> _pages;
  final afters = <HomeFeedPageToken?>[];

  @override
  Future<Either<Failure, HomeFeedPage>> getFeed({
    required bool signedIn,
    required String language,
    HomeFeedPageToken? after,
  }) async {
    afters.add(after);
    return Right(
      HomeFeedModel.parseMemberPage(
        _pages[afters.length - 1],
        language: 'en',
      ),
    );
  }
}

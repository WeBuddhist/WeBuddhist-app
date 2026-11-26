import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_poems_preview_provider.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/user_tradition_codes_provider.dart';
import 'package:flutter_pecha/features/poems/data/datasource/poems_remote_datasource.dart';
import 'package:flutter_pecha/features/poems/domain/entities/poem.dart';
import 'package:flutter_pecha/features/poems/presentation/providers/poems_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_screen_cache_store.dart';

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote extends PoemsRemoteDatasource {
  _FakeRemote() : super(dio: Dio());

  Object? response;
  Exception? error;
  int calls = 0;

  @override
  Future<Object> fetchPoemsJson({
    required String language,
    int skip = 0,
    int limit = 20,
    String? chapterName,
    String? authorName,
  }) async {
    calls++;
    if (error != null) throw error!;
    return response!;
  }
}

/// Codes start as [initial]; `null` keeps them loading until [set].
class _FakeCodes extends UserTraditionCodesNotifier {
  _FakeCodes(this.initial);

  final List<String>? initial;

  @override
  FutureOr<List<String>> build() => initial ?? Completer<List<String>>().future;

  void set(List<String> codes) => state = AsyncData(codes);
}

Map<String, dynamic> _page(List<String> ids) => {
  'poems': [
    for (final id in ids) {'id': id, 'title': 'Poem $id', 'content': '...'},
  ],
  'total': ids.length,
};

List<String> _ids(AsyncValue<List<Poem>> value) =>
    value.valueOrNull?.map((p) => p.id).toList() ?? const [];

void main() {
  late FakeScreenCacheStore store;
  late _FakeRemote remote;
  late _FakeCodes codes;

  String key(List<String> traditionCodes) => homePoemsPreviewKey(
    userId: store.userId,
    language: 'en',
    traditionCodes: traditionCodes,
  );

  setUp(() {
    store = FakeScreenCacheStore();
    remote = _FakeRemote();
  });

  ProviderContainer build({List<String>? traditionCodes = const ['tibetan']}) {
    codes = _FakeCodes(traditionCodes);
    final container = ProviderContainer(
      overrides: [
        contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
        poemsRemoteDatasourceProvider.overrideWithValue(remote),
        screenCacheStoreProvider.overrideWithValue(store),
        userTraditionCodesProvider.overrideWith(() => codes),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('stored preview shows first, then the refreshed one', () async {
    store.entries[key(['tibetan'])] = jsonEncode(_page(['p1']));
    remote.response = _page(['p1', 'p2']);
    final container = build();

    final seen = <List<String>>[];
    container.listen(homePoemsPreviewProvider, (_, next) {
      if (next.hasValue) seen.add(_ids(next));
    }, fireImmediately: true);
    await pumpEventQueue();

    expect(seen, [
      ['p1'],
      ['p1', 'p2'],
    ]);
    expect(remote.calls, 1);
  });

  test('another tradition\'s stored page never shows', () async {
    store.entries[key(['pali'])] = jsonEncode(_page(['pali-poem']));
    remote.response = _page(['tibetan-poem']);
    final container = build();

    final seen = <List<String>>[];
    container.listen(homePoemsPreviewProvider, (_, next) {
      if (next.hasValue) seen.add(_ids(next));
    }, fireImmediately: true);
    await pumpEventQueue();

    expect(seen, [
      ['tibetan-poem'],
    ]);
    expect(store.entries[key(['tibetan'])], isNotNull);
  });

  test('a guest\'s page is keyed as All traditions', () {
    expect(key(const []), isNot(key(const ['tibetan'])));
    expect(key(const []), endsWith(':all'));
    expect(key(const ['pali', 'tibetan']), endsWith(':pali-tibetan'));
  });

  test('waits for the tradition codes before fetching', () async {
    remote.response = _page(['p1']);
    final container = build(traditionCodes: null);
    container.listen(homePoemsPreviewProvider, (_, __) {});
    await pumpEventQueue();
    expect(container.read(homePoemsPreviewProvider).isLoading, isTrue);
    expect(remote.calls, 0);

    codes.set(const ['tibetan']);
    await pumpEventQueue();
    expect(_ids(container.read(homePoemsPreviewProvider)), ['p1']);
    expect(remote.calls, 1);
  });

  test('a tradition change re-fetches under the new key', () async {
    remote.response = _page(['tibetan-poem']);
    final container = build();
    container.listen(homePoemsPreviewProvider, (_, __) {});
    await pumpEventQueue();
    expect(remote.calls, 1);

    remote.response = _page(['pali-poem']);
    codes.set(const ['pali']);
    await pumpEventQueue();
    expect(_ids(container.read(homePoemsPreviewProvider)), ['pali-poem']);
    expect(remote.calls, 2);
    expect(store.entries[key(['pali'])], isNotNull);
  });

  test('a failure with nothing stored is an empty preview', () async {
    remote.error = const NetworkException('offline');
    final container = build();
    container.listen(homePoemsPreviewProvider, (_, __) {});
    await pumpEventQueue();
    final value = container.read(homePoemsPreviewProvider);
    expect(value.hasValue, isTrue);
    expect(_ids(value), isEmpty);
  });
}

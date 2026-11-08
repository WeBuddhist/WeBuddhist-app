import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/features/onboarding/data/datasource/onboarding_remote_datasource.dart';
import 'package:flutter_pecha/features/onboarding/data/models/tradition_models.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/onboarding_datasource_providers.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/tradition_tag_filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_screen_cache_store.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuth(super.state);

  void set(AuthState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote extends OnboardingRemoteDatasource {
  _FakeRemote() : super(dio: Dio());

  List<Tradition> catalog = const [
    Tradition(code: 'pali', name: 'Theravada', libraryTagId: 'TAG_PA'),
    Tradition(code: 'tibetan', name: 'Vajrayana', libraryTagId: 'TAG_TI'),
  ];
  List<String> selected = const ['tibetan'];
  bool fail = false;
  int catalogCalls = 0;
  int selectedCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<Tradition>> fetchTraditions() async {
    catalogCalls++;
    await gate?.future;
    if (fail) throw Exception('down');
    return catalog;
  }

  @override
  Future<List<UserTradition>> fetchUserTraditions({
    required String language,
  }) async {
    selectedCalls++;
    await gate?.future;
    if (fail) throw Exception('down');
    return [
      for (final code in selected)
        UserTradition(id: 'id-$code', traditionCode: code, traditionName: code),
    ];
  }
}

const _signedIn = AuthState(isLoggedIn: true);
const _guest = AuthState(isLoggedIn: false, isGuest: true);
const _booting = AuthState(isLoggedIn: false, isLoading: true);

void main() {
  late FakeScreenCacheStore store;
  late _FakeRemote remote;
  late _FakeAuth auth;
  late ProviderContainer container;
  late List<AsyncValue<List<String>>> states;

  ProviderContainer build(AuthState initial) {
    auth = _FakeAuth(initial);
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        screenCacheStoreProvider.overrideWithValue(store),
        onboardingRemoteDatasourceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(c.dispose);
    states = [];
    c.listen(
      traditionTagFilterProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    return c;
  }

  setUp(() {
    store = FakeScreenCacheStore();
    remote = _FakeRemote();
  });

  String key() => TraditionTagFilterNotifier.storageKey(store);

  test('a guest gets no filter at once and nothing is fetched', () async {
    container = build(_guest);
    expect(states.single.value, []);
    await pumpEventQueue();
    expect(remote.catalogCalls, 0);
    expect(remote.selectedCalls, 0);
  });

  test('a signed-out user gets no filter', () async {
    container = build(const AuthState(isLoggedIn: false));
    expect(states.single.value, []);
  });

  test('stays loading while auth boots, then resolves', () async {
    container = build(_booting);
    expect(states.single.isLoading, isTrue);
    await pumpEventQueue();
    expect(remote.catalogCalls, 0);

    auth.set(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, ['TAG_TI']);
    expect(remote.catalogCalls, 1);
    expect(remote.selectedCalls, 1);
  });

  test('first resolution is stored for the next launch', () async {
    container = build(_signedIn);
    expect(states.single.isLoading, isTrue);
    await pumpEventQueue();
    expect(states.last.value, ['TAG_TI']);
    expect(jsonDecode(store.entries[key()]!), ['TAG_TI']);
  });

  test(
    'the stored tags are the first value, the server result replaces it',
    () async {
      store.entries[key()] = jsonEncode(['TAG_PA']);
      remote.gate = Completer<void>();
      container = build(_signedIn);
      expect(states.single.value, ['TAG_PA']);

      remote.gate!.complete();
      await pumpEventQueue();
      expect(states.last.value, ['TAG_TI']);
      expect(jsonDecode(store.entries[key()]!), ['TAG_TI']);
    },
  );

  test('an unchanged server result emits nothing new', () async {
    store.entries[key()] = jsonEncode(['TAG_TI']);
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states, hasLength(1));
    expect(remote.catalogCalls, 1);
  });

  test('a failed lookup keeps the stored tags', () async {
    store.entries[key()] = jsonEncode(['TAG_PA']);
    remote.fail = true;
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.single.value, ['TAG_PA']);
    expect(jsonDecode(store.entries[key()]!), ['TAG_PA']);
  });

  test(
    'a failed lookup with nothing stored means no filter, not an error',
    () async {
      remote.fail = true;
      container = build(_signedIn);
      await pumpEventQueue();
      expect(states.last.value, []);
      expect(states.last.hasError, isFalse);
      expect(store.entries[key()], isNull);
    },
  );

  test('unreadable stored tags are ignored', () async {
    store.entries[key()] = '{not a list';
    container = build(_signedIn);
    expect(states.single.isLoading, isTrue);
    await pumpEventQueue();
    expect(states.last.value, ['TAG_TI']);
  });

  test('invalidating after a tradition change re-resolves', () async {
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, ['TAG_TI']);

    remote.selected = const ['pali', 'tibetan'];
    container.invalidate(traditionTagFilterProvider);
    await pumpEventQueue();
    // Both tagged traditions: "show me everything".
    expect(states.last.value, []);
    expect(remote.catalogCalls, 2);
  });

  test('a stale resolution does not overwrite a newer build', () async {
    container = build(_signedIn);
    await pumpEventQueue();

    // The second build holds its requests while the user signs out.
    remote.selected = const ['pali'];
    remote.gate = Completer<void>();
    container.invalidate(traditionTagFilterProvider);
    await pumpEventQueue();
    expect(states.last.value, ['TAG_TI']);
    auth.set(_guest);
    await pumpEventQueue();
    expect(states.last.value, []);

    remote.gate!.complete();
    await pumpEventQueue();
    expect(states.last.value, []);
  });

  test('signing out clears the filter', () async {
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, ['TAG_TI']);
    auth.set(const AuthState(isLoggedIn: false));
    await pumpEventQueue();
    expect(states.last.value, []);
  });
}

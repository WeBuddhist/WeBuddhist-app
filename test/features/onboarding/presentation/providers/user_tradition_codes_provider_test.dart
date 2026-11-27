import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/network/network_info.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/onboarding/data/datasource/onboarding_remote_datasource.dart';
import 'package:flutter_pecha/features/onboarding/data/models/tradition_models.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/onboarding_datasource_providers.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/user_tradition_codes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';
import '../../../../helpers/fake_screen_cache_store.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuth(super.state);

  void set(AuthState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote extends OnboardingRemoteDatasource {
  _FakeRemote() : super(dio: Dio());

  List<String> selected = const ['tibetan'];
  bool fail = false;
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<List<UserTradition>> fetchUserTraditions({
    required String language,
  }) async {
    calls++;
    // Taken at call time so an older call can finish with an older selection.
    final picked = selected;
    await gate?.future;
    if (fail) throw Exception('down');
    return [
      for (final code in picked)
        UserTradition(id: 'id-$code', traditionCode: code, traditionName: code),
    ];
  }
}

class _FakeNetwork implements NetworkInfo {
  final controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => true;

  @override
  Future<bool> checkConnectivity() async => true;

  @override
  Stream<bool> get onConnectivityChanged => controller.stream;
}

const _signedIn = AuthState(isLoggedIn: true);
const _guest = AuthState(isLoggedIn: false, isGuest: true);
const _booting = AuthState(isLoggedIn: false, isLoading: true);

void main() {
  late FakeScreenCacheStore store;
  late _FakeRemote remote;
  late _FakeAuth auth;
  late _FakeNetwork network;
  late RecordingAnalyticsService analytics;
  late ProviderContainer container;
  late List<AsyncValue<List<String>>> states;

  ProviderContainer build(AuthState initial) {
    auth = _FakeAuth(initial);
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        screenCacheStoreProvider.overrideWithValue(store),
        onboardingRemoteDatasourceProvider.overrideWithValue(remote),
        networkInfoProvider.overrideWithValue(network),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(c.dispose);
    states = [];
    c.listen(
      userTraditionCodesProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    return c;
  }

  setUp(() {
    store = FakeScreenCacheStore();
    remote = _FakeRemote();
    network = _FakeNetwork();
    analytics = RecordingAnalyticsService();
  });

  String key() => UserTraditionCodesNotifier.storageKey(store);

  test('a guest has no traditions and nothing is fetched', () async {
    container = build(_guest);
    expect(states.single.value, []);
    await pumpEventQueue();
    expect(remote.calls, 0);
  });

  test('stays loading while auth boots, then resolves', () async {
    container = build(_booting);
    expect(states.single.isLoading, isTrue);
    await pumpEventQueue();
    expect(remote.calls, 0);

    auth.set(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, ['tibetan']);
    expect(remote.calls, 1);
  });

  test('codes are sorted, de-duplicated and stored', () async {
    remote.selected = const ['tibetan', 'pali', 'tibetan'];
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, ['pali', 'tibetan']);
    expect(jsonDecode(store.entries[key()]!), ['pali', 'tibetan']);
  });

  test(
    'the stored codes are the first value, the server result replaces it',
    () async {
      store.entries[key()] = jsonEncode(['pali']);
      remote.gate = Completer<void>();
      container = build(_signedIn);
      expect(states.single.value, ['pali']);

      remote.gate!.complete();
      await pumpEventQueue();
      expect(states.last.value, ['tibetan']);
    },
  );

  test('an unchanged server result emits nothing new', () async {
    store.entries[key()] = jsonEncode(['tibetan']);
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states, hasLength(1));
  });

  test('a failed lookup keeps the stored codes, or none', () async {
    store.entries[key()] = jsonEncode(['pali']);
    remote.fail = true;
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.single.value, ['pali']);

    store.entries.clear();
    container.invalidate(userTraditionCodesProvider);
    await pumpEventQueue();
    expect(states.last.value, []);
    expect(states.last.hasError, isFalse);
  });

  test('invalidating after a tradition change re-resolves', () async {
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, ['tibetan']);

    remote.selected = const ['chinese'];
    container.invalidate(userTraditionCodesProvider);
    await pumpEventQueue();
    expect(states.last.value, ['chinese']);
    expect(remote.calls, 2);
  });

  test('signing out clears the codes', () async {
    container = build(_signedIn);
    await pumpEventQueue();
    auth.set(const AuthState(isLoggedIn: false));
    await pumpEventQueue();
    expect(states.last.value, []);
  });

  test('a failed lookup with nothing stored is retried on reconnect', () async {
    remote.fail = true;
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, []);

    remote.fail = false;
    network.controller.add(true);
    await pumpEventQueue();
    expect(states.last.value, ['tibetan']);
    expect(remote.calls, 2);
  });

  test('retryIfFailed re-resolves a failed lookup and settles first', () async {
    remote.fail = true;
    container = build(_signedIn);
    await pumpEventQueue();
    expect(states.last.value, []);

    remote.fail = false;
    await container.read(userTraditionCodesProvider.notifier).retryIfFailed();
    expect(container.read(userTraditionCodesProvider).value, ['tibetan']);
    expect(jsonDecode(store.entries[key()]!), ['tibetan']);
  });

  test('a failed retry keeps the codes and can be retried again', () async {
    store.entries[key()] = jsonEncode(['pali']);
    remote.fail = true;
    container = build(_signedIn);
    await pumpEventQueue();

    final notifier = container.read(userTraditionCodesProvider.notifier);
    await notifier.retryIfFailed();
    expect(states.last.value, ['pali']);
    expect(remote.calls, 2);

    remote.fail = false;
    await notifier.retryIfFailed();
    expect(states.last.value, ['tibetan']);
    expect(remote.calls, 3);
  });

  test('nothing is retried after a successful lookup', () async {
    container = build(_signedIn);
    await pumpEventQueue();

    await container.read(userTraditionCodesProvider.notifier).retryIfFailed();
    network.controller.add(true);
    await pumpEventQueue();
    expect(remote.calls, 1);
  });

  test(
    'an older lookup finishing last does not overwrite the stored codes',
    () async {
      final stale = remote.gate = Completer<void>();
      container = build(_signedIn);
      await pumpEventQueue();

      // A tradition edit re-resolves while the first lookup is still running.
      remote
        ..gate = null
        ..selected = const ['chinese'];
      container.invalidate(userTraditionCodesProvider);
      await pumpEventQueue();
      expect(states.last.value, ['chinese']);

      stale.complete();
      await pumpEventQueue();
      expect(jsonDecode(store.entries[key()]!), ['chinese']);
      expect(states.last.value, ['chinese']);
    },
  );

  group('reporting to analytics', () {
    test('the first lookup puts the traditions on the person', () async {
      remote.selected = const ['tibetan', 'pali'];
      container = build(_signedIn);
      await pumpEventQueue();

      expect(analytics.eventNames, [AnalyticsEvents.traditionsChanged]);
      expect(analytics.events.single.properties, {
        'traditions_count': 2,
        'is_first_report': true,
        r'$set': {
          'traditions': ['theravada', 'vajrayana'],
        },
      });
    });

    test('unchanged codes are not reported again in a later session', () async {
      container = build(_signedIn);
      await pumpEventQueue();
      expect(analytics.events, hasLength(1));

      // A new session: same account, same store, same answer from the server.
      container = build(_signedIn);
      await pumpEventQueue();
      expect(remote.calls, 2);
      expect(analytics.events, hasLength(1));
    });

    test('a tradition edit is reported as a change', () async {
      container = build(_signedIn);
      await pumpEventQueue();

      remote.selected = const ['chinese'];
      container.invalidate(userTraditionCodesProvider);
      await pumpEventQueue();

      expect(analytics.events, hasLength(2));
      expect(analytics.events.last.properties, {
        'traditions_count': 1,
        'is_first_report': false,
        r'$set': {
          'traditions': ['mahayana'],
        },
      });
    });

    test('an account with no traditions reports an empty list once', () async {
      remote.selected = const [];
      container = build(_signedIn);
      await pumpEventQueue();
      container.invalidate(userTraditionCodesProvider);
      await pumpEventQueue();

      expect(analytics.events.single.properties, {
        'traditions_count': 0,
        'is_first_report': true,
        r'$set': {'traditions': <String>[]},
      });
    });

    test('another account on the same device gets its own report', () async {
      container = build(_signedIn);
      await pumpEventQueue();

      store.userId = 'user-2';
      container.invalidate(userTraditionCodesProvider);
      await pumpEventQueue();

      expect(analytics.events, hasLength(2));
      expect(analytics.events.last.properties['is_first_report'], isTrue);
    });

    test('a guest and a failed lookup report nothing', () async {
      container = build(_guest);
      await pumpEventQueue();

      remote.fail = true;
      container = build(_signedIn);
      await pumpEventQueue();

      expect(analytics.events, isEmpty);
    });

    test('a lookup from before a rebuild does not report', () async {
      final stale = remote.gate = Completer<void>();
      container = build(_signedIn);
      await pumpEventQueue();

      remote
        ..gate = null
        ..selected = const ['chinese'];
      container.invalidate(userTraditionCodesProvider);
      await pumpEventQueue();
      stale.complete();
      await pumpEventQueue();

      expect(analytics.events, hasLength(1));
      expect(analytics.events.single.properties[r'$set'], {
        'traditions': ['mahayana'],
      });
    });
  });
}

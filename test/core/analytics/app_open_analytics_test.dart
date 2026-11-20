import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/core/analytics/app_open_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements AppOpenStore {
  final Map<String, Object> values = {};

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

typedef _Event = List<Object>;

class _Harness {
  _Harness({_MemoryStore? store, String version = '2.0.0', String build = '42'})
    : store = store ?? _MemoryStore() {
    tracker = AppOpenAnalytics(
      store: this.store,
      capture: (event, props) async => events.add([event, props]),
      onFirstOpen: () async => firstOpens++,
      buildInfo: () async => AppBuildInfo(version: version, build: build),
    );
  }

  final _MemoryStore store;
  final List<_Event> events = [];
  int firstOpens = 0;
  late final AppOpenAnalytics tracker;

  Future<void> states(List<AppLifecycleState> states) async {
    for (final state in states) {
      await tracker.handleLifecycleState(state);
    }
  }
}

const _coldOpen = [
  'Application Opened',
  {'from_background': false, 'version': '2.0.0', 'build': 42},
];

void main() {
  group('first UI open', () {
    test('a fresh install sends Installed, then Opened', () async {
      final h = _Harness();

      await h.states([AppLifecycleState.resumed]);

      expect(h.events, [
        [
          'Application Installed',
          {'version': '2.0.0', 'build': 42},
        ],
        _coldOpen,
      ]);
      expect(h.firstOpens, 1);
      expect(h.store.values[AppOpenAnalytics.buildKey], '42');
      expect(h.store.values[AppOpenAnalytics.versionKey], '2.0.0');
    });

    test('a headless start sends nothing and keeps the gate shut', () async {
      final h = _Harness();

      // audio_service's engine gets no lifecycle state; iOS background
      // launches get no resumed.
      await h.states([AppLifecycleState.inactive, AppLifecycleState.hidden]);

      expect(h.events, isEmpty);
      expect(h.firstOpens, 0);
      expect(h.store.values, isEmpty, reason: 'next UI open is the install');
    });

    test('a headless start opened later counts the install then', () async {
      final store = _MemoryStore();
      await _Harness(store: store).states([AppLifecycleState.paused]);

      final h = _Harness(store: store);
      await h.states([AppLifecycleState.resumed]);

      expect(h.events.first[0], 'Application Installed');
    });

    test('the same build again sends only Opened', () async {
      final store = _MemoryStore();
      await _Harness(store: store).states([AppLifecycleState.resumed]);

      final h = _Harness(store: store);
      await h.states([AppLifecycleState.resumed]);

      expect(h.events, [_coldOpen]);
    });

    test('a new build sends Updated with the previous one', () async {
      final store = _MemoryStore();
      await _Harness(
        store: store,
        version: '1.9.0',
        build: '40',
      ).states([AppLifecycleState.resumed]);

      final h = _Harness(store: store);
      await h.states([AppLifecycleState.resumed]);

      expect(h.events, [
        [
          'Application Updated',
          {
            'previous_version': '1.9.0',
            'previous_build': 40,
            'version': '2.0.0',
            'build': 42,
          },
        ],
        _coldOpen,
      ]);
    });

    test('a non-numeric build is sent as text', () async {
      final h = _Harness(build: '42-beta');

      await h.states([AppLifecycleState.resumed]);

      expect((h.events.first[1] as Map)['build'], '42-beta');
    });
  });

  group('foreground and background', () {
    test('returning from background is Opened from_background', () async {
      final h = _Harness();

      await h.states([
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

      expect(h.events.skip(2).toList(), [
        ['Application Backgrounded', <String, Object>{}],
        [
          'Application Opened',
          {'from_background': true},
        ],
      ]);
      expect(h.firstOpens, 1);
    });

    test('a dialog or control centre (inactive only) is not an open', () async {
      final h = _Harness();

      await h.states([
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

      expect(h.events, hasLength(2));
    });
  });

  group('migration of installs from before this tracking', () {
    test('PostHog\'s stored build makes the update an Updated', () async {
      final store = _MemoryStore();
      await AppOpenAnalytics.migrate(
        store: store,
        probe: () async => const LegacyInstall(version: '1.9.0', build: '40'),
      );

      final h = _Harness(store: store);
      await h.states([AppLifecycleState.resumed]);

      expect(h.events.first, [
        'Application Updated',
        {
          'previous_version': '1.9.0',
          'previous_build': 40,
          'version': '2.0.0',
          'build': 42,
        },
      ]);
    });

    test('app data alone makes it an Updated without previous', () async {
      final store = _MemoryStore();
      await AppOpenAnalytics.migrate(
        store: store,
        probe: () async => const LegacyInstall(),
      );

      final h = _Harness(store: store);
      await h.states([AppLifecycleState.resumed]);
      expect(h.events.first, [
        'Application Updated',
        {'version': '2.0.0', 'build': 42},
      ]);

      // Only that once.
      final again = _Harness(store: store);
      await again.states([AppLifecycleState.resumed]);
      expect(again.events, [_coldOpen]);
    });

    test('nothing found is a fresh install', () async {
      final store = _MemoryStore();
      await AppOpenAnalytics.migrate(store: store, probe: () async => null);

      final h = _Harness(store: store);
      await h.states([AppLifecycleState.resumed]);

      expect(h.events.first[0], 'Application Installed');
    });

    test('runs once, so PostHog\'s later writes are never read', () async {
      final store = _MemoryStore();
      await AppOpenAnalytics.migrate(store: store, probe: () async => null);

      var probed = false;
      await AppOpenAnalytics.migrate(
        store: store,
        probe: () async {
          probed = true;
          return const LegacyInstall(version: '2.0.0', build: '42');
        },
      );

      expect(probed, isFalse);
      expect(store.values[AppOpenAnalytics.buildKey], isNull);
    });

    test('a failed probe is retried on the next start', () async {
      final store = _MemoryStore();
      await AppOpenAnalytics.migrate(
        store: store,
        probe: () async => throw Exception('prefs unavailable'),
      );

      expect(store.values[AppOpenAnalytics.migratedKey], isNull);
    });
  });

  testWidgets('attach counts an app that is already resumed', (tester) async {
    final h = _Harness();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    h.tracker.attach(tester.binding);
    await tester.pump();

    expect(h.firstOpens, 1);
    tester.binding.removeObserver(h.tracker);
  });
}

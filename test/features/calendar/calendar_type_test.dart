import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/storage/storage_service.dart';
import 'package:flutter_pecha/features/calendar/data/datasource/calendar_remote_datasource.dart';
import 'package:flutter_pecha/features/calendar/domain/models/calendar_type.dart';
import 'package:flutter_pecha/features/calendar/presentation/providers/calendar_event_sources_providers.dart';
import 'package:flutter_pecha/features/calendar/presentation/providers/calendar_type_providers.dart';
import 'package:flutter_pecha/features/calendar/presentation/providers/tibetan_calendar_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_screen_cache_store.dart';

/// Records each request and answers with [reply].
class _Recorder extends Interceptor {
  _Recorder(this.reply);

  final Object? reply;
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: reply),
    );
  }
}

class _MemoryStorage implements StorageService {
  _MemoryStorage([Map<String, Object?>? values]) : values = {...?values};

  final Map<String, Object?> values;

  @override
  Future<T?> get<T>(String key) async => values[key] as T?;

  @override
  Future<bool> set<T>(String key, T value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> delete(String key) async => values.remove(key) != null;

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `GET /calendar/types` as production serves it.
const _apiTypes = [
  {
    'tradition': 'vajrayana',
    'types': ['phugpa', 'tsurphu', 'nyingmapa'],
  },
  {
    'tradition': 'theravada',
    'types': ['sinhalese', 'thai', 'burmese', 'lao'],
  },
  {
    'tradition': 'mahayana',
    'types': ['chinese', 'vietnamese', 'korean', 'japanese'],
  },
];

Map<String, List<String>> _asMap(List<CalendarTradition> traditions) => {
  for (final t in traditions) t.code: t.types,
};

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('calendar types', () {
    test('parse by tradition, skipping malformed rows', () {
      final parsed = CalendarTradition.listFromJson([
        ..._apiTypes,
        {'tradition': '', 'types': <String>[]},
        {
          'types': <String>['x'],
        },
        'junk',
      ]);
      expect(parsed.map((t) => t.code), ['vajrayana', 'theravada', 'mahayana']);
      expect(parsed.first.types, ['phugpa', 'tsurphu', 'nyingmapa']);
    });

    test('the datasource reads GET /calendar/types', () async {
      final recorder = _Recorder(_apiTypes);
      final remote = CalendarRemoteDatasource(
        dio: Dio()..interceptors.add(recorder),
      );
      final types = await remote.fetchTypes();
      expect(recorder.requests.single.path, '/calendar/types');
      expect(types, hasLength(3));
    });

    test('month and today ask for the chosen calendar', () async {
      final recorder = _Recorder({'year': 2026, 'month': 11, 'days': []});
      final remote = CalendarRemoteDatasource(
        dio: Dio()..interceptors.add(recorder),
      );
      await remote.fetchMonthJson(2026, 11, calendarType: 'tsurphu');
      await remote.fetchMonthJson(2026, 12);
      expect(recorder.requests[0].path, '/calendar/2026/11');
      expect(recorder.requests[0].queryParameters, {
        'calendar_type': 'tsurphu',
      });
      expect(recorder.requests[1].queryParameters, {'calendar_type': 'phugpa'});
    });
  });

  group('calendar choices', () {
    final all = CalendarTradition.listFromJson(_apiTypes);

    test('only calendars the backend computes are offered', () {
      expect(_asMap(calendarChoices(all, selected: 'phugpa')), {
        'vajrayana': ['phugpa', 'tsurphu', 'nyingmapa'],
      });
    });

    test('a guest or a viewer without traditions sees every one', () {
      final guest = calendarChoices(all, selected: 'phugpa');
      final none = calendarChoices(
        all,
        selected: 'phugpa',
        userTraditions: const {},
      );
      expect(_asMap(none), _asMap(guest));
    });

    test('a viewer sees only their own traditions', () {
      final everything = [
        for (final t in all)
          CalendarTradition(code: t.code, types: [...t.types, 'phugpa']),
      ];
      // Pretend every tradition had a supported calendar.
      final choices = calendarChoices(
        everything,
        selected: 'tsurphu',
        userTraditions: const {'tibetan'},
      );
      expect(choices.map((t) => t.code), ['vajrayana']);
    });

    test('the current calendar stays listed outside the viewer traditions', () {
      final choices = calendarChoices(
        all,
        selected: 'nyingmapa',
        userTraditions: const {'pali'},
      );
      expect(_asMap(choices), {
        'vajrayana': ['phugpa', 'tsurphu', 'nyingmapa'],
      });
    });
  });

  group('selected calendar', () {
    test('defaults to Phugpa', () async {
      final notifier = SelectedCalendarTypeNotifier(_MemoryStorage());
      await _settle();
      expect(notifier.state, defaultCalendarType);
    });

    test('restores the stored calendar', () async {
      final notifier = SelectedCalendarTypeNotifier(
        _MemoryStorage({StorageKeys.calendarType: 'nyingmapa'}),
      );
      await _settle();
      expect(notifier.state, 'nyingmapa');
    });

    test('a stored calendar the app no longer supports falls back', () async {
      final notifier = SelectedCalendarTypeNotifier(
        _MemoryStorage({StorageKeys.calendarType: 'martian'}),
      );
      await _settle();
      expect(notifier.state, defaultCalendarType);
    });

    test('a pick is kept, and an unsupported one ignored', () async {
      final storage = _MemoryStorage();
      final notifier = SelectedCalendarTypeNotifier(storage);
      await notifier.select('tsurphu');
      expect(notifier.state, 'tsurphu');
      expect(storage.values[StorageKeys.calendarType], 'tsurphu');

      await notifier.select('thai');
      expect(notifier.state, 'tsurphu');
    });
  });

  group('switching calendars', () {
    final month = DateTime(2026, 11, 1);
    final day = DateTime(2026, 11, 10);

    /// Each calendar puts Nov 10 on its own lunar day, so the screen shows
    /// which calendar answered.
    const lunarDayOf = {'phugpa': 20, 'tsurphu': 21};

    ({ProviderContainer container, _CalendarServer server}) build({
      bool hold = false,
    }) {
      final server = _CalendarServer(lunarDayOf, hold: hold);
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(_MemoryStorage()),
          dioProvider.overrideWithValue(Dio()..interceptors.add(server)),
          screenCacheStoreProvider.overrideWithValue(FakeScreenCacheStore()),
          calendarViewerProvider.overrideWithValue((
            id: 'me',
            name: 'Tenzin',
            avatarUrl: null,
          )),
        ],
      );
      addTearDown(container.dispose);
      // What the open calendar screen and Repeats sheet keep alive.
      container.listen(resolvedDayProvider(day), (_, __) {});
      container.listen(monthEventsProvider(month), (_, __) {});
      container.listen(personalRepeatOptionsProvider(day), (_, __) {});
      return (container: container, server: server);
    }

    int shownLunarDay(ProviderContainer c) =>
        c.read(resolvedDayProvider(day)).lunarDay;

    int? feedLunarDay(ProviderContainer c) =>
        c
            .read(monthEventsProvider(month))
            .where((e) => e.eventId == 'p1')
            .singleOrNull
            ?.lunarDay;

    int? repeatDay(ProviderContainer c) =>
        c.read(personalRepeatOptionsProvider(day)).valueOrNull?.single.day;

    test('refetches months, the feed and repeat choices in the new calendar',
        () async {
      final (:container, :server) = build();
      await pumpEventQueue();
      expect(shownLunarDay(container), 20);
      expect(feedLunarDay(container), 20);
      expect(repeatDay(container), 20);
      expect(server.typesAsked, {'phugpa'});

      server.requests.clear();
      await container
          .read(selectedCalendarTypeProvider.notifier)
          .select('tsurphu');
      await pumpEventQueue();

      expect(server.pathsAsked('tsurphu'), containsAll(<String>[
        '/calendar/2026/11',
        '/users/me/calendar',
        '/users/me/calendar-events/repeat-options',
      ]));
      expect(server.typesAsked, {'tsurphu'});
      expect(shownLunarDay(container), 21);
      expect(feedLunarDay(container), 21);
      expect(repeatDay(container), 21);
    });

    test('a late answer in the old calendar does not replace the new one',
        () async {
      final (:container, :server) = build(hold: true);
      await pumpEventQueue();
      expect(server.pathsAsked('phugpa'), isNotEmpty);

      await container
          .read(selectedCalendarTypeProvider.notifier)
          .select('tsurphu');
      await pumpEventQueue();

      server.answer('tsurphu');
      await pumpEventQueue();
      expect(shownLunarDay(container), 21);
      expect(feedLunarDay(container), 21);
      expect(repeatDay(container), 21);

      // The Phugpa requests sent before the switch finish last.
      server.answer('phugpa');
      await pumpEventQueue();
      expect(shownLunarDay(container), 21);
      expect(feedLunarDay(container), 21);
      expect(repeatDay(container), 21);
    });
  });
}

/// Answers the calendar, feed and repeat-options endpoints in whichever
/// calendar each request asks for. With [hold], requests wait for [answer].
class _CalendarServer extends Interceptor {
  _CalendarServer(this.lunarDayOf, {this.hold = false});

  final Map<String, int> lunarDayOf;
  final bool hold;
  final requests = <RequestOptions>[];
  final _held = <(RequestOptions, RequestInterceptorHandler)>[];

  Set<String> get typesAsked => {
    for (final r in requests)
      if (r.queryParameters['calendar_type'] case final String type) type,
  };

  List<String> pathsAsked(String calendarType) => [
    for (final r in requests)
      if (r.queryParameters['calendar_type'] == calendarType) r.path,
  ];

  /// Answers every held request for [calendarType].
  void answer(String calendarType) {
    final ready =
        _held
            .where((h) => h.$1.queryParameters['calendar_type'] == calendarType)
            .toList();
    for (final h in ready) {
      _held.remove(h);
      _resolve(h.$1, h.$2);
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    if (hold) {
      _held.add((options, handler));
    } else {
      _resolve(options, handler);
    }
  }

  void _resolve(RequestOptions options, RequestInterceptorHandler handler) {
    final type = options.queryParameters['calendar_type'] as String?;
    final lunarDay = lunarDayOf[type] ?? 1;
    final Object data = switch (options.path) {
      '/calendar/2026/11' => {
        'year': 2026,
        'month': 11,
        'days': [
          {
            'gregorian_date': '2026-11-10',
            'lunar_day': lunarDay,
            'lunar_month': {'month': 9},
          },
        ],
      },
      '/users/me/calendar' => {
        'has_more': false,
        'items': [
          {
            'kind': 'PERSONAL',
            'id': 'p1',
            'date': '2026-11-10',
            'title': 'Birthday',
            'all_day': true,
            'repeat': 'MONTHLY_LUNAR',
            'repeat_day': lunarDay,
            'lunar_day': lunarDay,
          },
        ],
      },
      '/users/me/calendar-events/repeat-options' => {
        'options': [
          {
            'repeat': 'MONTHLY_LUNAR',
            'day': lunarDay,
            'next_dates': ['2026-12-09'],
          },
        ],
      },
      _ when options.path.startsWith('/calendar/') => {'days': <Object>[]},
      _ => <String, Object>{},
    };
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: data),
    );
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_local_datasource.dart';
import 'package:flutter_pecha/features/home/data/datasource/verse_of_day_remote_datasource.dart';
import 'package:flutter_pecha/features/home/data/models/verse_of_day_model.dart';
import 'package:flutter_pecha/features/home/data/repositories/verse_of_day_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the Hive-backed store. Keys are `<lang>` (or
/// `<lang>:<tradition>`), then `:<date>` for day entries.
class _FakeLocal extends HomeLocalDatasource {
  final entries = <String, VerseOfDayCacheEntry>{};
  final today = <String, VerseOfDayModel>{};
  final datesByScope = <String, List<String>>{};
  final _changes = StreamController<void>.broadcast();

  static String scope(String language, String? tradition) =>
      tradition == null ? language : '$language:$tradition';

  /// The All traditions `en` week.
  List<String>? get dates => datesByScope['en'];
  set dates(List<String>? value) =>
      value == null ? datesByScope.remove('en') : datesByScope['en'] = value;

  @override
  Stream<void> watchKey(String key) => _changes.stream;

  @override
  VerseOfDayModel? readVerseOfDay(String language, {String? tradition}) =>
      today[scope(language, tradition)];

  @override
  Future<void> saveVerseOfDay(
    String language,
    VerseOfDayModel verse, {
    String? tradition,
  }) async {
    today[scope(language, tradition)] = verse;
  }

  @override
  VerseOfDayCacheEntry? readVerseOfDayEntry(
    String language,
    String date, {
    String? tradition,
  }) => entries['${scope(language, tradition)}:$date'];

  @override
  Future<void> saveVerseOfDayEntry(
    String language,
    String date,
    VerseOfDayCacheEntry entry, {
    String? tradition,
  }) async {
    entries['${scope(language, tradition)}:$date'] = entry;
  }

  @override
  List<String>? readRecentVerseDates(String language, {String? tradition}) =>
      datesByScope[scope(language, tradition)];

  @override
  Future<void> saveRecentVerseDates(
    String language,
    List<String> dates, {
    String? tradition,
  }) async {
    datesByScope[scope(language, tradition)] = [...dates];
    _changes.add(null);
  }
}

class _FakeRemote extends VerseOfDayRemoteDatasource {
  _FakeRemote() : super(dio: Dio());

  VerseOfDayModel? todayVerse;
  Exception? todayError;
  final byDate = <String, VerseOfDayModel>{};
  final dateErrors = <String, Exception>{};
  final dateCalls = <String>[];

  /// Today's verse per tradition; [todayVerse] answers the rest.
  final todayByTradition = <String, VerseOfDayModel>{};
  final todayTraditions = <String?>[];
  final dateTraditions = <String?>[];

  /// When set, today's call waits for it before answering.
  Completer<void>? todayGate;

  @override
  Future<VerseOfDayModel?> fetchVerseOfDay({
    required String language,
    String? tradition,
  }) async {
    todayTraditions.add(tradition);
    await todayGate?.future;
    if (todayError != null) throw todayError!;
    return todayByTradition[tradition] ?? todayVerse;
  }

  @override
  Future<VerseOfDayModel?> fetchVerseOfDayByDate({
    required String language,
    required String date,
    String? tradition,
  }) async {
    dateCalls.add(date);
    dateTraditions.add(tradition);
    final error = dateErrors[date];
    if (error != null) throw error;
    return byDate[date];
  }
}

VerseOfDayModel _verse(String date) => VerseOfDayModel(
  id: 'id-$date',
  verse: 'Verse for $date',
  imageUrl: 'https://example.com/$date.webp',
  refId: '',
  refType: '',
  date: date,
);

void main() {
  late _FakeLocal local;
  late _FakeRemote remote;
  late DateTime now;
  late VerseOfDayRepository repository;

  setUp(() {
    local = _FakeLocal();
    remote = _FakeRemote();
    now = DateTime(2026, 11, 10, 9);
    repository = VerseOfDayRepository(
      remote: remote,
      local: local,
      now: () => now,
    );
  });

  test('anchors on the server\'s date and skips days with no verse', () async {
    // Server is already on the 11th while the device is on the 10th.
    remote.todayVerse = _verse('2026-11-11');
    for (final date in ['2026-11-10', '2026-11-08', '2026-11-05']) {
      remote.byDate[date] = _verse(date);
    }

    final result = await repository.refreshRecentVerses(language: 'en');

    expect(result.isRight(), isTrue);
    expect(remote.dateCalls.toSet(), {
      '2026-11-10',
      '2026-11-09',
      '2026-11-08',
      '2026-11-07',
      '2026-11-06',
      '2026-11-05',
    });
    expect(local.readRecentVerses('en')!.map((v) => v.date), [
      '2026-11-11',
      '2026-11-10',
      '2026-11-08',
      '2026-11-05',
    ]);
    expect(local.today['en']?.date, '2026-11-11');
  });

  test('uses the device date when nothing is published today', () async {
    remote.byDate['2026-11-09'] = _verse('2026-11-09');

    await repository.refreshRecentVerses(language: 'en');

    expect(local.dates!.first, '2026-11-10');
    expect(local.readRecentVerses('en')!.map((v) => v.date), ['2026-11-09']);
  });

  test('does not re-fetch past days fetched within 23 hours', () async {
    remote.todayVerse = _verse('2026-11-10');
    remote.byDate['2026-11-09'] = _verse('2026-11-09');
    await repository.refreshRecentVerses(language: 'en');
    remote.dateCalls.clear();

    now = now.add(const Duration(hours: 22));
    await repository.refreshRecentVerses(language: 'en');
    expect(remote.dateCalls, isEmpty);

    // A day later the presigned image links are about to expire.
    now = now.add(const Duration(hours: 2));
    await repository.refreshRecentVerses(language: 'en');
    expect(remote.dateCalls, hasLength(6));
  });

  test('a failed past day keeps its old entry', () async {
    remote.todayVerse = _verse('2026-11-10');
    remote.byDate['2026-11-09'] = _verse('2026-11-09');
    await repository.refreshRecentVerses(language: 'en');

    now = now.add(const Duration(days: 1));
    remote.dateErrors['2026-11-09'] = const NetworkException('offline');
    final result = await repository.refreshRecentVerses(language: 'en');

    expect(result.isRight(), isTrue);
    expect(
      local.readRecentVerses('en')!.map((v) => v.date),
      contains('2026-11-09'),
    );
  });

  test('a failed today call fails the refresh and stores nothing', () async {
    remote.todayError = const NetworkException('offline');

    final result = await repository.refreshRecentVerses(language: 'en');

    expect(result.isLeft(), isTrue);
    expect(local.dates, isNull);
  });

  test('watch yields the cached week, then the refreshed one', () async {
    local.dates = ['2026-11-09'];
    local.entries['en:2026-11-09'] = VerseOfDayCacheEntry(
      fetchedAt: now,
      verse: _verse('2026-11-09'),
    );
    remote.todayVerse = _verse('2026-11-10');

    final first = await repository
        .watchRecentVerses(language: 'en')
        .take(2)
        .toList();

    expect(
      first.map((r) => r.getOrElse((_) => []).map((v) => v.date).toList()),
      [
        ['2026-11-09'],
        ['2026-11-10', '2026-11-09'],
      ],
    );
  });

  test('before the week is stored, the single saved verse stands in', () async {
    // An install from before the carousel: only verse_of_day:<lang> exists.
    local.today['en'] = _verse('2026-11-09');
    remote.todayError = const NetworkException('offline');

    final first =
        await repository.watchRecentVerses(language: 'en').first;

    expect(first.getOrElse((_) => []).map((v) => v.date), ['2026-11-09']);
  });

  test(
    'a week stored while the first refresh runs still reaches the watcher',
    () async {
      local.dates = ['2026-11-09'];
      local.entries['en:2026-11-09'] = VerseOfDayCacheEntry(
        fetchedAt: now,
        verse: _verse('2026-11-09'),
      );
      remote.todayGate = Completer<void>();
      final emitted = <List<String>>[];
      final subscription = repository
          .watchRecentVerses(language: 'en')
          .listen(
            (r) =>
                emitted.add(r.getOrElse((_) => []).map((v) => v.date).toList()),
          );
      await pumpEventQueue();

      // A pull-to-refresh stores the new week while the first refresh waits,
      // and the first refresh then fails.
      local.entries['en:2026-11-10'] = VerseOfDayCacheEntry(
        fetchedAt: now,
        verse: _verse('2026-11-10'),
      );
      await local.saveRecentVerseDates('en', ['2026-11-10', '2026-11-09']);
      remote.todayError = const NetworkException('offline');
      remote.todayGate!.complete();
      await pumpEventQueue();

      expect(emitted.last, ['2026-11-10', '2026-11-09']);
      // An async* stream stops at its next yield, so the cancel isn't
      // awaited while it waits for another store write.
      unawaited(subscription.cancel());
    },
  );

  test('watch with no cache reports a failed refresh', () async {
    remote.todayError = const NetworkException('offline');

    final first =
        await repository.watchRecentVerses(language: 'en').first;

    expect(first.isLeft(), isTrue);
  });

  test('each tradition is asked for and stored on its own', () async {
    remote.todayVerse = _verse('2026-11-10');
    remote.todayByTradition['pali'] = VerseOfDayModel(
      id: 'theravada-verse',
      verse: 'Theravada verse',
      imageUrl: 'https://example.com/pali.webp',
      refId: '',
      refType: '',
      date: '2026-11-10',
    );

    await repository.refreshRecentVerses(language: 'en', tradition: 'pali');

    expect(remote.todayTraditions, ['pali']);
    expect(remote.dateTraditions.toSet(), {'pali'});
    expect(
      local.readRecentVerses('en', tradition: 'pali')!.map((v) => v.id),
      ['theravada-verse'],
    );
    // The All traditions week is untouched, so a switch never shows it.
    expect(local.readRecentVerses('en'), isNull);

    await repository.refreshRecentVerses(language: 'en');
    expect(remote.todayTraditions.last, isNull);
    expect(local.readRecentVerses('en')!.map((v) => v.id), ['id-2026-11-10']);
  });
}

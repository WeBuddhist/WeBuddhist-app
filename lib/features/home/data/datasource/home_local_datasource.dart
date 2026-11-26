import 'dart:async';
import 'dart:convert';

import 'package:flutter_pecha/core/storage/preferences_service.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/home/data/models/routine_info_model.dart';
import 'package:flutter_pecha/features/home/data/models/series_model.dart';
import 'package:flutter_pecha/features/home/data/models/today_event_model.dart';
import 'package:flutter_pecha/features/home/data/models/verse_of_day_model.dart';
import 'package:flutter_pecha/features/plans/data/models/response/featured_day_response.dart';
import 'package:hive_flutter/hive_flutter.dart';

final _logger = AppLogger('HomeLocalDatasource');

/// Persistent local source of truth for Home.
///
/// This is intentionally not wired through the TTL cache service: Home must keep the
/// last known good data available offline even when a TTL would have expired.
class HomeLocalDatasource {
  static const String boxName = 'home_local_data';

  Box<String> get _box => Hive.box<String>(boxName);

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<String>(boxName);
      _logger.info('HomeLocalDatasource initialized');
    }
  }

  Future<String?> currentUserId() {
    return SharedPreferencesService.instance.get<String>(
      StorageKeys.currentUserId,
    );
  }

  /// Same id without an await, so a screen can seed its first frame.
  String? get currentUserIdSync {
    return SharedPreferencesService.instance.getSync<String>(
      StorageKeys.currentUserId,
    );
  }

  Stream<void> watchKey(String key) async* {
    await for (final _ in _box.watch(key: key)) {
      yield null;
    }
  }

  String featuredDayKey(String language) => 'featured_day:$language';
  String tagsKey(String language) => 'tags:$language';
  // v3: entries cached before the request sent auth lack progress/partner.
  String featuredSeriesKey(String language, int limit) =>
      'featured_series:v3:$language:$limit';
  String seriesListKey(String language) => 'series_list:$language';
  String seriesByIdKey(String language, String id) =>
      'series:v2:$language:$id';
  // v2: entries cached before group_avatar_url was read lack the avatar.
  String todayEventsKey(String language) => 'today_events:v2:$language';
  // Verse of the Day is per tradition (null: the All traditions feed), so
  // each tradition keeps its own week. v2: v1 entries weren't per tradition.
  String _verseScope(String language, String? tradition) =>
      'v2:$language:${tradition ?? 'all'}';
  String verseOfDayKey(String language, {String? tradition}) =>
      'verse_of_day:${_verseScope(language, tradition)}';
  String verseOfDayByDatePrefix(String language, {String? tradition}) =>
      'verse_of_day_date:${_verseScope(language, tradition)}:';
  String verseOfDayByDateKey(
    String language,
    String date, {
    String? tradition,
  }) => '${verseOfDayByDatePrefix(language, tradition: tradition)}$date';
  String recentVerseDatesKey(String language, {String? tradition}) =>
      'verse_of_day_recent:${_verseScope(language, tradition)}';
  String routineInfoKey(String userId) => 'routine_info:$userId';
  String streakKey(String userId) => 'streak:$userId';
  String enrollmentsKey(String userId) => 'series_enrollments:$userId';
  String pendingEnrollmentsKey(String userId) =>
      'pending_series_enrollments:$userId';

  FeaturedDayResponse? readFeaturedDay(String language) {
    return _readObject(featuredDayKey(language), FeaturedDayResponse.fromJson);
  }

  Future<void> saveFeaturedDay(String language, FeaturedDayResponse response) {
    return _writeObject(featuredDayKey(language), response.toJson());
  }

  List<String>? readTags(String language) {
    return _readStringList(tagsKey(language));
  }

  Future<void> saveTags(String language, List<String> tags) {
    return _writeList(tagsKey(language), tags);
  }

  List<SeriesModel>? readFeaturedSeries(String language, int limit) {
    return _readModelList(
      featuredSeriesKey(language, limit),
      SeriesModel.fromJson,
    );
  }

  Future<void> saveFeaturedSeries(
    String language,
    int limit,
    List<SeriesModel> series,
  ) async {
    await _writeModelList(
      featuredSeriesKey(language, limit),
      series.map((s) => s.toJson()).toList(),
    );
  }

  List<SeriesModel>? readSeriesList(String language) {
    return _readModelList(seriesListKey(language), SeriesModel.fromJson);
  }

  Future<void> saveSeriesList(String language, List<SeriesModel> series) async {
    await _writeModelList(
      seriesListKey(language),
      series.map((s) => s.toJson()).toList(),
    );
  }

  SeriesModel? readSeriesById(String language, String id) {
    return _readObject(seriesByIdKey(language, id), SeriesModel.fromJson);
  }

  Future<void> saveSeriesById(String language, SeriesModel series) {
    return _writeObject(seriesByIdKey(language, series.id), series.toJson());
  }

  List<TodayEventModel>? readTodayEvents(String language) {
    return _readModelList(todayEventsKey(language), TodayEventModel.fromJson);
  }

  Future<void> saveTodayEvents(String language, List<TodayEventModel> events) {
    return _writeModelList(
      todayEventsKey(language),
      events.map((e) => e.toJson()).toList(),
    );
  }

  VerseOfDayModel? readVerseOfDay(String language, {String? tradition}) {
    return _readObject(
      verseOfDayKey(language, tradition: tradition),
      VerseOfDayModel.fromJson,
    );
  }

  Future<void> saveVerseOfDay(
    String language,
    VerseOfDayModel verse, {
    String? tradition,
  }) {
    return _writeObject(
      verseOfDayKey(language, tradition: tradition),
      verse.toJson(),
    );
  }

  VerseOfDayCacheEntry? readVerseOfDayEntry(
    String language,
    String date, {
    String? tradition,
  }) {
    return _readObject(
      verseOfDayByDateKey(language, date, tradition: tradition),
      VerseOfDayCacheEntry.fromJson,
    );
  }

  Future<void> saveVerseOfDayEntry(
    String language,
    String date,
    VerseOfDayCacheEntry entry, {
    String? tradition,
  }) {
    return _writeObject(
      verseOfDayByDateKey(language, date, tradition: tradition),
      entry.toJson(),
    );
  }

  /// The week's dates, newest first, including days with no verse.
  List<String>? readRecentVerseDates(String language, {String? tradition}) {
    return _readStringList(recentVerseDatesKey(language, tradition: tradition));
  }

  /// Stores the week's [dates] and drops cached days that fell out of it.
  /// Written after the day entries, so a watcher of
  /// [recentVerseDatesKey] sees the whole week at once.
  Future<void> saveRecentVerseDates(
    String language,
    List<String> dates, {
    String? tradition,
  }) async {
    final prefix = verseOfDayByDatePrefix(language, tradition: tradition);
    final keep = {for (final date in dates) '$prefix$date'};
    final stale =
        _box.keys
            .whereType<String>()
            .where((key) => key.startsWith(prefix) && !keep.contains(key))
            .toList();
    if (stale.isNotEmpty) await _box.deleteAll(stale);
    await _writeList(
      recentVerseDatesKey(language, tradition: tradition),
      dates,
    );
  }

  /// The cached week, newest first, without the days that have no verse.
  /// Until the week is first stored, falls back to the single verse that
  /// installs from before the carousel kept, so Home still has it offline.
  /// Null when neither was ever stored.
  List<VerseOfDayModel>? readRecentVerses(
    String language, {
    String? tradition,
  }) {
    final dates = readRecentVerseDates(language, tradition: tradition);
    if (dates == null) {
      final verse = readVerseOfDay(language, tradition: tradition);
      return verse == null ? null : [verse];
    }
    return [
      for (final date in dates)
        if (readVerseOfDayEntry(language, date, tradition: tradition)?.verse
            case final verse?)
          verse,
    ];
  }

  RoutineInfoModel? readRoutineInfo(String userId) {
    return _readObject(routineInfoKey(userId), RoutineInfoModel.fromJson);
  }

  Future<void> saveRoutineInfo(String userId, RoutineInfoModel info) {
    return _writeObject(routineInfoKey(userId), info.toJson());
  }

  int? readStreak(String userId) {
    final raw = _box.get(streakKey(userId));
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  Future<void> saveStreak(String userId, int streak) {
    return _box.put(streakKey(userId), streak.toString());
  }

  Set<String>? readEnrollments(String userId) {
    return _readStringList(enrollmentsKey(userId))?.toSet();
  }

  Future<void> saveEnrollments(String userId, Set<String> ids) {
    return _writeList(enrollmentsKey(userId), ids.toList()..sort());
  }

  Set<String> readPendingEnrollments(String userId) {
    return _readStringList(pendingEnrollmentsKey(userId))?.toSet() ??
        const <String>{};
  }

  Future<void> enqueueEnrollment(String userId, String seriesId) async {
    final pending = {...readPendingEnrollments(userId), seriesId};
    await _writeList(pendingEnrollmentsKey(userId), pending.toList()..sort());

    final enrollments = {...?readEnrollments(userId), seriesId};
    await saveEnrollments(userId, enrollments);
  }

  Future<void> removePendingEnrollment(String userId, String seriesId) {
    final pending = {...readPendingEnrollments(userId)}..remove(seriesId);
    return _writeList(pendingEnrollmentsKey(userId), pending.toList()..sort());
  }

  /// Undoes [enqueueEnrollment] when the server rejected the enrollment, so
  /// the Enroll button comes back. Leaves [seriesId] in the enrollments when
  /// [keepEnrolled] (the user was already enrolled before this attempt).
  Future<void> discardEnrollment(
    String userId,
    String seriesId, {
    bool keepEnrolled = false,
  }) async {
    await removePendingEnrollment(userId, seriesId);
    if (keepEnrolled) return;
    final enrollments = readEnrollments(userId);
    if (enrollments == null || !enrollments.contains(seriesId)) return;
    await saveEnrollments(userId, {...enrollments}..remove(seriesId));
  }

  T? _readObject<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      _logger.error('Failed to read home object for $key', e, st);
      return null;
    }
  }

  List<T>? _readModelList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.error('Failed to read home list for $key', e, st);
      return null;
    }
  }

  List<String>? _readStringList(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toList();
    } catch (e, st) {
      _logger.error('Failed to read string list for $key', e, st);
      return null;
    }
  }

  Future<void> _writeObject(String key, Map<String, dynamic> data) {
    return _box.put(key, jsonEncode(data));
  }

  Future<void> _writeModelList(String key, List<Map<String, dynamic>> data) {
    return _box.put(key, jsonEncode(data));
  }

  Future<void> _writeList(String key, List<String> data) {
    return _box.put(key, jsonEncode(data));
  }
}

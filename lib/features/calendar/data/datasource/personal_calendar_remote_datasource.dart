import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/utils/iana_timezone.dart';
import 'package:flutter_pecha/features/calendar/data/models/personal_calendar_models.dart';
import 'package:flutter_pecha/features/calendar/domain/models/calendar_event.dart';
import 'package:flutter_pecha/features/calendar/domain/models/personal_calendar_event.dart';

/// The Personal Calendar API. Failures reach the repository as exceptions.
class PersonalCalendarRemoteDatasource {
  PersonalCalendarRemoteDatasource({required this.dio});

  final Dio dio;

  static const _eventsPath = '/users/me/calendar-events';
  static final _noCache = Options(extra: {'no_cache': true});

  Future<CalendarFeedPage> fetchFeed({
    required DateTime from,
    required DateTime to,
    required String language,
    required int skip,
    required int limit,
    required String calendarType,
  }) async {
    final response = await dio.get(
      '/users/me/calendar',
      queryParameters: {
        'from_date': formatApiDate(from),
        'to_date': formatApiDate(to),
        'calendar_type': calendarType,
        'language': language,
        'skip': skip,
        'limit': limit,
      },
      options: _noCache,
    );
    return calendarFeedPageFromJson(response.data as Map<String, dynamic>);
  }

  Future<PersonalCalendarEvent> fetchEvent(String id) async {
    final response = await dio.get('$_eventsPath/$id', options: _noCache);
    return personalEventFromJson(response.data as Map<String, dynamic>);
  }

  /// Saved without a start time, which makes it all day. A lunar repeat is
  /// kept in [calendarType], the calendar the viewer chose its day in.
  Future<PersonalCalendarEvent> createEvent({
    required String title,
    required DateTime startDate,
    required PersonalRepeat repeat,
    required String calendarType,
  }) async {
    final response = await dio.post(
      _eventsPath,
      data: {
        'title': title,
        'start_date': formatApiDate(startDate),
        'timezone': await IanaTimezone.resolve(),
        'repeat': repeat.apiValue,
        'calendar_type': calendarType,
      },
    );
    return personalEventFromJson(response.data as Map<String, dynamic>);
  }

  /// The API is sparse: fields left out stay as they are.
  Future<PersonalCalendarEvent> updateEvent(
    String id, {
    required String title,
    required PersonalRepeat repeat,
    required String calendarType,
  }) async {
    final response = await dio.patch(
      '$_eventsPath/$id',
      data: {
        'title': title,
        'repeat': repeat.apiValue,
        'calendar_type': calendarType,
      },
    );
    return personalEventFromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String id) async {
    await dio.delete('$_eventsPath/$id');
  }

  Future<List<PersonalRepeatOption>> fetchRepeatOptions(
    DateTime date, {
    required String calendarType,
  }) async {
    final response = await dio.get(
      '$_eventsPath/repeat-options',
      queryParameters: {
        'date': formatApiDate(date),
        'calendar_type': calendarType,
      },
      options: _noCache,
    );
    return repeatOptionsFromJson(response.data as Map<String, dynamic>);
  }
}

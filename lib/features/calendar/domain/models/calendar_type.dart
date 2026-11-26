/// The calendars a viewer can pick from, grouped by tradition, as served by
/// `GET /calendar/types`: e.g. `vajrayana` → `phugpa`, `tsurphu`, `nyingmapa`.
///
/// Codes stay raw API strings; labels come from `calendar_type_l10n.dart`.
class CalendarTradition {
  const CalendarTradition({required this.code, required this.types});

  /// `vajrayana`, `theravada`, `mahayana`, …
  final String code;

  /// Calendar type codes in the order the API lists them.
  final List<String> types;

  static List<CalendarTradition> listFromJson(Object? json) {
    if (json is! List) {
      throw FormatException('Calendar types: expected a list', json);
    }
    final traditions = <CalendarTradition>[];
    for (final row in json) {
      if (row is! Map) continue;
      final code = row['tradition'];
      final types = row['types'];
      if (code is! String || code.isEmpty || types is! List) continue;
      traditions.add(
        CalendarTradition(
          code: code,
          types: types
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toList(growable: false),
        ),
      );
    }
    return traditions;
  }
}

/// The calendar used until the viewer picks another; also the backend default.
const defaultCalendarType = 'phugpa';

/// Calendar types the backend computes days for (its `CalendarType` enum).
/// `GET /calendar/types` already lists Theravada and Mahayana calendars, but
/// `/calendar/{year}/{month}` rejects them, so they stay hidden until the
/// backend serves them; add their codes here when it does.
const supportedCalendarTypes = <String>{'phugpa', 'tsurphu', 'nyingmapa'};

/// What the picker offers when `GET /calendar/types` cannot be reached.
const fallbackCalendarTraditions = <CalendarTradition>[
  CalendarTradition(
    code: 'vajrayana',
    types: ['phugpa', 'tsurphu', 'nyingmapa'],
  ),
];

/// User traditions (`GET /users/me/traditions`, codes from `GET /traditions`)
/// → the matching calendar tradition.
const calendarTraditionByUserTradition = <String, String>{
  'tibetan': 'vajrayana',
  'pali': 'theravada',
  'chinese': 'mahayana',
};

/// The traditions and calendars the "Choose calendar" sheet lists.
///
/// Only [supportedCalendarTypes] are offered, and traditions left with none
/// are dropped. With [userTraditions] (codes from `GET /traditions`), only the
/// viewer's traditions are listed, plus the one holding [selected] so the
/// current choice is always visible. If that leaves nothing, every supported
/// calendar is listed.
List<CalendarTradition> calendarChoices(
  List<CalendarTradition> all, {
  required String selected,
  Set<String>? userTraditions,
}) {
  final supported = [
    for (final tradition in all)
      CalendarTradition(
        code: tradition.code,
        types: tradition.types
            .where(supportedCalendarTypes.contains)
            .toList(growable: false),
      ),
  ].where((t) => t.types.isNotEmpty).toList(growable: false);

  if (userTraditions == null || userTraditions.isEmpty) return supported;

  final wanted = {
    for (final code in userTraditions)
      if (calendarTraditionByUserTradition[code] case final mapped?) mapped,
  };
  final mine = supported
      .where((t) => wanted.contains(t.code) || t.types.contains(selected))
      .toList(growable: false);
  return mine.isEmpty ? supported : mine;
}

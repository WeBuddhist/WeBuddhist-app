/// How many days the verse-of-the-day carousel covers. The backend deletes
/// verses older than about a week, so this is also all the history there is.
const verseOfDayWeekLength = 7;

/// `YYYY-MM-DD` for the calendar day of [date], as the API's `date` takes it.
String verseOfDayDateKey(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-'
      '${two(date.day)}';
}

/// Local noon of a `YYYY-MM-DD` date, or null when [value] isn't one.
DateTime? parseVerseOfDayDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day, 12);
  // Rejects dates DateTime would roll over, like 2026-02-30.
  if (date.month != month || date.day != day) return null;
  return date;
}

/// [count] dates ending on [anchor], newest first, as `YYYY-MM-DD`.
///
/// Steps back by calendar day at local noon, so a daylight-saving change
/// can't skip or repeat a day.
List<String> daysEndingOn(DateTime anchor, int count) {
  return [
    for (var i = 0; i < count; i++)
      verseOfDayDateKey(DateTime(anchor.year, anchor.month, anchor.day - i, 12)),
  ];
}

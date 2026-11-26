import 'package:flutter_pecha/core/utils/tibetan_numerals.dart';
import 'package:flutter_pecha/features/home/domain/utils/verse_of_day_dates.dart';
import 'package:intl/intl.dart';

/// The pill on a verse card: [todayLabel] for the device's today, else a
/// short date ("Sun, Nov 8") in [intlLocale]. Empty when [date] isn't a
/// date, so the card can leave the pill out.
///
/// [intlLocale] must come from `intlFormatLocaleOf` — `intl` has no `bo`
/// data, so Tibetan gets the English pattern with Tibetan digits.
String verseOfDayDateLabel({
  required String date,
  required DateTime now,
  required String todayLabel,
  required String intlLocale,
  required bool useTibetanDigits,
}) {
  final parsed = parseVerseOfDayDate(date);
  if (parsed == null) return '';
  if (verseOfDayDateKey(parsed) == verseOfDayDateKey(now)) return todayLabel;
  final label = DateFormat.MMMEd(intlLocale).format(parsed);
  return useTibetanDigits ? toTibetanDigits(label) : label;
}

import 'package:flutter_pecha/features/home/domain/utils/verse_of_day_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daysEndingOn', () {
    test('counts back from the anchor, newest first', () {
      expect(daysEndingOn(DateTime(2026, 11, 10, 8), 7), [
        '2026-11-10',
        '2026-11-09',
        '2026-11-08',
        '2026-11-07',
        '2026-11-06',
        '2026-11-05',
        '2026-11-04',
      ]);
    });

    test('crosses month and year boundaries', () {
      expect(daysEndingOn(DateTime(2027, 1, 2), 4), [
        '2027-01-02',
        '2027-01-01',
        '2026-12-31',
        '2026-12-30',
      ]);
      expect(daysEndingOn(DateTime(2028, 3, 1), 2), [
        '2028-03-01',
        '2028-02-29',
      ]);
    });

    test('a daylight-saving week neither skips nor repeats a day', () {
      // Spans the US (Mar 8) and EU (Mar 29) spring-forward days and the
      // EU fall-back day (Oct 25), whatever zone the test runs in.
      for (final anchor in [
        DateTime(2026, 3, 10, 0, 30),
        DateTime(2026, 3, 31, 23, 30),
        DateTime(2026, 10, 27),
      ]) {
        final days = daysEndingOn(anchor, 7);
        expect(days.toSet(), hasLength(7));
        for (var i = 1; i < days.length; i++) {
          final newer = parseVerseOfDayDate(days[i - 1])!;
          final older = parseVerseOfDayDate(days[i])!;
          expect(
            DateTime.utc(newer.year, newer.month, newer.day)
                .difference(DateTime.utc(older.year, older.month, older.day)),
            const Duration(days: 1),
          );
        }
      }
    });
  });

  group('parseVerseOfDayDate', () {
    test('reads a date and ignores a time part', () {
      expect(parseVerseOfDayDate('2026-11-08'), DateTime(2026, 11, 8, 12));
      expect(
        parseVerseOfDayDate('2026-11-08T00:00:00Z'),
        DateTime(2026, 11, 8, 12),
      );
    });

    test('rejects blanks and impossible dates', () {
      expect(parseVerseOfDayDate(''), isNull);
      expect(parseVerseOfDayDate('Nov 8'), isNull);
      expect(parseVerseOfDayDate('2026-02-30'), isNull);
    });
  });
}

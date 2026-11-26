import 'package:flutter_pecha/features/home/presentation/utils/verse_of_day_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  final now = DateTime(2026, 11, 10, 23, 30);

  String label(String date, {String locale = 'en', bool tibetan = false}) =>
      verseOfDayDateLabel(
        date: date,
        now: now,
        todayLabel: 'Today',
        intlLocale: locale,
        useTibetanDigits: tibetan,
      );

  test('today\'s date reads as Today', () {
    expect(label('2026-11-10'), 'Today');
  });

  test('a past day reads as a short date', () {
    expect(label('2026-11-08'), 'Sun, Nov 8');
    expect(label('2026-11-05'), 'Thu, Nov 5');
  });

  test('Tibetan uses the English pattern with Tibetan digits', () {
    expect(label('2026-11-07', tibetan: true), 'Sat, Nov ༧');
  });

  test('follows the locale\'s pattern', () {
    expect(label('2026-11-08', locale: 'zh'), isNot('Sun, Nov 8'));
  });

  test('no pill for a missing or broken date', () {
    expect(label(''), isEmpty);
    expect(label('soon'), isEmpty);
  });
}

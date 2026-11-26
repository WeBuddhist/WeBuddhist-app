import 'package:flutter_pecha/features/home/domain/utils/verse_of_day_tradition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('verseOfDayTradition', () {
    test('Theravada wins over Vajrayana and Mahayana', () {
      expect(verseOfDayTradition(['chinese', 'tibetan', 'pali']), 'pali');
    });

    test('Vajrayana wins over Mahayana', () {
      expect(verseOfDayTradition(['chinese', 'tibetan']), 'tibetan');
    });

    test('a single tradition is used as is', () {
      expect(verseOfDayTradition(['chinese']), 'chinese');
    });

    test('no known tradition leaves the param out', () {
      expect(verseOfDayTradition(const []), isNull);
      expect(verseOfDayTradition(['unknown']), isNull);
    });
  });
}

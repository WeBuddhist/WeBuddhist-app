import 'package:flutter_pecha/shared/domain/visible_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('visibleUserName', () {
    test('prefers the display name, trimmed', () {
      expect(
        visibleUserName(
          displayName: '  Tenz  ',
          fullname: 'Tenzin Dorje',
          username: 'tenzin',
        ),
        'Tenz',
      );
    });

    test('skips a blank display name for the full name', () {
      expect(
        visibleUserName(
          displayName: '   ',
          fullname: 'Tenzin Dorje',
          username: 'tenzin',
        ),
        'Tenzin Dorje',
      );
    });

    test('falls back to the username when both names are blank', () {
      expect(
        visibleUserName(displayName: null, fullname: ' ', username: 'tenzin'),
        'tenzin',
      );
    });

    test('returns the fallback when nothing is set', () {
      expect(visibleUserName(), '');
      expect(
        visibleUserName(username: '  ', fallback: 'Participant'),
        'Participant',
      );
    });
  });
}

import 'package:flutter_pecha/features/auth/data/session/firebase_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitDisplayName', () {
    test('splits at the first space', () {
      expect(splitDisplayName('Tenzin Dolma'), (first: 'Tenzin', last: 'Dolma'));
      expect(splitDisplayName('Tenzin Dolma Lhamo'), (
        first: 'Tenzin',
        last: 'Dolma Lhamo',
      ));
    });

    test('a single name has no last name', () {
      expect(splitDisplayName('Tenzin'), (first: 'Tenzin', last: null));
    });

    test('ignores surrounding and repeated whitespace', () {
      expect(splitDisplayName('  Tenzin   Dolma  '), (
        first: 'Tenzin',
        last: 'Dolma',
      ));
    });

    test('nothing in, nothing out', () {
      expect(splitDisplayName(null), (first: null, last: null));
      expect(splitDisplayName('   '), (first: null, last: null));
    });
  });

  test('a cancelled sign-in is told apart from a failed one', () {
    expect(
      const FirebaseSignInException(FirebaseSignInException.cancelled)
          .isCancelled,
      isTrue,
    );
    expect(
      const FirebaseSignInException('invalid-verification-code').isCancelled,
      isFalse,
    );
  });
}

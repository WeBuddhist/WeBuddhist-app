import 'package:flutter_pecha/features/auth/domain/entities/account_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const placeholder = AccountNames.placeholder;

  group('complete', () {
    test('keeps a full name as it is', () {
      expect(
        AccountNames.complete('Tenzin', 'Dolma'),
        const AccountNames(first: 'Tenzin', last: 'Dolma'),
      );
    });

    test('a single name stands for both', () {
      expect(
        AccountNames.complete('Tenzin', null),
        const AccountNames(first: 'Tenzin', last: 'Tenzin'),
      );
      expect(
        AccountNames.complete('  ', 'Dolma'),
        const AccountNames(first: 'Dolma', last: 'Dolma'),
      );
    });

    test('no name at all is the placeholder', () {
      expect(AccountNames.complete(null, null), placeholder);
      expect(AccountNames.complete('', '   '), placeholder);
    });

    test('tidies whitespace', () {
      expect(
        AccountNames.complete(' Tenzin ', 'Dolma   Lhamo'),
        const AccountNames(first: 'Tenzin', last: 'Dolma Lhamo'),
      );
    });
  });

  group('fromDisplayName', () {
    test('splits at the first space', () {
      expect(
        AccountNames.fromDisplayName('Pema Lhamo Dolkar'),
        const AccountNames(first: 'Pema', last: 'Lhamo Dolkar'),
      );
    });

    test('a single word stands for both', () {
      expect(
        AccountNames.fromDisplayName(' Pema '),
        const AccountNames(first: 'Pema', last: 'Pema'),
      );
    });

    test('nothing typed gives nothing', () {
      expect(AccountNames.fromDisplayName(null), isNull);
      expect(AccountNames.fromDisplayName('   '), isNull);
    });
  });

  group('isPlaceholder', () {
    test('true only for the placeholder itself', () {
      expect(
        AccountNames.isPlaceholder(placeholder.first, placeholder.last),
        isTrue,
      );
      expect(
        AccountNames.isPlaceholder(' ${placeholder.first} ', placeholder.last),
        isTrue,
      );
      expect(AccountNames.isPlaceholder('Tenzin', placeholder.last), isFalse);
      expect(AccountNames.isPlaceholder(placeholder.first, 'Dolma'), isFalse);
      expect(AccountNames.isPlaceholder(null, null), isFalse);
    });
  });
}

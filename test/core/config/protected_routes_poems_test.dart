import 'package:flutter_pecha/core/config/protected_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtectedRoutes poems', () {
    test(
      'the poems feed is optional auth, so traditions come from the token',
      () {
        expect(ProtectedRoutes.isOptional('/poems'), isTrue);
        expect(ProtectedRoutes.isProtected('/poems'), isFalse);
      },
    );

    test('a single poem stays public', () {
      expect(ProtectedRoutes.isOptional('/poems/p1'), isFalse);
      expect(ProtectedRoutes.isProtected('/poems/p1'), isFalse);
    });
  });
}

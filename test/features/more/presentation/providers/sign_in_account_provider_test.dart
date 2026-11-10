import 'dart:convert';

import 'package:flutter_pecha/features/more/presentation/providers/sign_in_account_provider.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, dynamic> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

void main() {
  group('signInMethodFromUserId', () {
    test('reads the Auth0 connection prefix', () {
      expect(signInMethodFromUserId('google-oauth2|1'), SignInMethod.google);
      expect(signInMethodFromUserId('apple|1'), SignInMethod.apple);
      expect(signInMethodFromUserId('sms|1'), SignInMethod.phone);
      expect(signInMethodFromUserId('auth0|1'), isNull);
      expect(signInMethodFromUserId(null), isNull);
    });
  });

  group('resolveSignInAccount', () {
    test('uses the profile email for Google', () {
      expect(
        resolveSignInAccount(
          userId: 'google-oauth2|1',
          email: ' tenzin@example.com ',
        ),
        const SignInAccount(
          method: SignInMethod.google,
          identifier: 'tenzin@example.com',
        ),
      );
    });

    test('falls back to the token email when the profile has none', () {
      expect(
        resolveSignInAccount(
          userId: 'apple|1',
          claims: {'email': 'x@privaterelay.appleid.com'},
        ),
        const SignInAccount(
          method: SignInMethod.apple,
          identifier: 'x@privaterelay.appleid.com',
        ),
      );
    });

    test('prefers phone_number for phone sign-in', () {
      expect(
        resolveSignInAccount(
          userId: 'sms|1',
          email: 'ignored@example.com',
          claims: {'phone_number': '+66812345678', 'name': '+1 555 0100'},
        )?.identifier,
        '+66812345678',
      );
    });

    test('uses a phone-shaped name claim for phone sign-in', () {
      expect(
        resolveSignInAccount(userId: 'sms|1', claims: {'name': '+66812345678'}),
        const SignInAccount(
          method: SignInMethod.phone,
          identifier: '+66812345678',
        ),
      );
    });

    test('ignores a name claim that is not a phone number', () {
      expect(
        resolveSignInAccount(userId: 'sms|1', claims: {'name': 'Tenzin'}),
        isNull,
      );
    });

    test('takes the method from the token when no user id is stored', () {
      expect(
        resolveSignInAccount(
          userId: null,
          email: 'tenzin@example.com',
          claims: {'sub': 'google-oauth2|1'},
        )?.method,
        SignInMethod.google,
      );
    });

    test('keeps an unknown connection without a method', () {
      expect(
        resolveSignInAccount(userId: 'auth0|1', email: 'tenzin@example.com'),
        const SignInAccount(method: null, identifier: 'tenzin@example.com'),
      );
    });
  });

  group('decodeJwtClaims', () {
    test('decodes the payload', () {
      expect(decodeJwtClaims(_jwt({'sub': 'sms|1'})), {'sub': 'sms|1'});
    });

    test('returns null for a malformed token', () {
      expect(decodeJwtClaims('not-a-jwt'), isNull);
      expect(decodeJwtClaims('a.b.c'), isNull);
    });
  });
}

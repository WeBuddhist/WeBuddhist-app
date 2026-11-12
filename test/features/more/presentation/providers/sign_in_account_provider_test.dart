import 'dart:convert';

import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/network/connectivity_service.dart'
    show ConnectivityNotifier, connectivityNotifierProvider;
import 'package:flutter_pecha/features/auth/domain/entities/auth_credentials.dart';
import 'package:flutter_pecha/features/auth/domain/entities/user.dart';
import 'package:flutter_pecha/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/user_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/state/user_state.dart';
import 'package:flutter_pecha/features/more/presentation/providers/sign_in_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

String _jwt(Map<String, dynamic> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

class _User extends StateNotifier<UserState> implements UserNotifier {
  _User() : super(const UserState(user: User(id: 'me')));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers each getCredentials call with the next queued result.
class _AuthRepository implements AuthRepository {
  _AuthRepository(this.results);

  final List<Either<Failure, AuthCredentials>> results;
  int calls = 0;

  @override
  Future<Either<Failure, AuthCredentials>> getCredentials() async =>
      results[calls++];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connectivity extends ConnectivityNotifier {
  _Connectivity(this.initial);

  final bool initial;

  @override
  bool build() => initial;

  void set(bool isOnline) => state = isOnline;
}

AuthCredentials _credentials(String idToken) => AuthCredentials(
  accessToken: 'a',
  idToken: idToken,
  tokenType: 'Bearer',
  expiresIn: 3600,
  obtainedAt: DateTime(2026),
);

void main() {
  group('signInAccountProvider', () {
    test('looks again once back online after an offline failure', () async {
      final repository = _AuthRepository([
        const Left(NetworkFailure('offline')),
        Right(
          _credentials(_jwt({'sub': 'sms|1', 'phone_number': '+66812345678'})),
        ),
      ]);
      final connectivity = _Connectivity(false);
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _User()),
          authRepositoryProvider.overrideWithValue(repository),
          connectivityNotifierProvider.overrideWith(() => connectivity),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(signInAccountProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(signInAccountProvider.future), isNull);

      connectivity.set(true);

      expect(
        await container.read(signInAccountProvider.future),
        const SignInAccount(
          method: SignInMethod.phone,
          identifier: '+66812345678',
        ),
      );
      expect(repository.calls, 2);
    });

    test('does not retry after a lost session', () async {
      final repository = _AuthRepository([
        const Left(AuthenticationFailure('signed out')),
      ]);
      final connectivity = _Connectivity(false);
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _User()),
          authRepositoryProvider.overrideWithValue(repository),
          connectivityNotifierProvider.overrideWith(() => connectivity),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(signInAccountProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(signInAccountProvider.future), isNull);
      container.read(connectivityNotifierProvider);
      connectivity.set(true);
      await Future<void>.delayed(Duration.zero);

      expect(repository.calls, 1);
    });
  });

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

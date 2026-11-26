import 'dart:convert';

import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/network/connectivity_service.dart'
    show ConnectivityNotifier, connectivityNotifierProvider;
import 'package:flutter_pecha/core/storage/preferences_service.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

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
  @override
  void cancelPhoneSignIn() {}

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

AuthCredentials _credentials(String accessToken) => AuthCredentials(
  accessToken: accessToken,
  tokenType: 'Bearer',
  expiresIn: 3600,
  obtainedAt: DateTime(2026),
);

void main() {
  group('signInAccountProvider', () {
    setUpAll(() => SharedPreferences.setMockInitialValues({}));
    tearDown(
      () => SharedPreferencesService.instance.delete(StorageKeys.signInMethod),
    );

    test('looks again once back online after an offline failure', () async {
      // What a phone sign-in stores; a phone account has no email to show.
      await SharedPreferencesService.instance.set(
        StorageKeys.signInMethod,
        'phone',
      );
      final repository = _AuthRepository([
        const Left(NetworkFailure('offline')),
        Right(
          _credentials(_jwt({'sub': 'u-1', 'phone_number': '+66812345678'})),
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

  group('signInMethodFromStored', () {
    test('reads what was stored at sign-in', () {
      expect(signInMethodFromStored('google'), SignInMethod.google);
      expect(signInMethodFromStored('apple'), SignInMethod.apple);
      expect(signInMethodFromStored('phone'), SignInMethod.phone);
      expect(signInMethodFromStored('sms'), isNull);
      expect(signInMethodFromStored(null), isNull);
    });
  });

  group('resolveSignInAccount', () {
    test('uses the profile email for Google', () {
      expect(
        resolveSignInAccount(
          method: SignInMethod.google,
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
          method: SignInMethod.apple,
          claims: {'email': 'x@privaterelay.appleid.com'},
        ),
        const SignInAccount(
          method: SignInMethod.apple,
          identifier: 'x@privaterelay.appleid.com',
        ),
      );
    });

    test('shows the phone number for phone sign-in, not a linked email', () {
      expect(
        resolveSignInAccount(
          method: SignInMethod.phone,
          email: 'linked@example.com',
          claims: {'phone_number': '+66812345678', 'name': 'Tenzin Dolma'},
        ),
        const SignInAccount(
          method: SignInMethod.phone,
          identifier: '+66812345678',
        ),
      );
    });

    test('shows the email for Google, not a linked phone number', () {
      expect(
        resolveSignInAccount(
          method: SignInMethod.google,
          claims: {'email': 'tenzin@example.com', 'phone_number': '+1555'},
        )?.identifier,
        'tenzin@example.com',
      );
    });

    test('a phone sign-in with no phone number resolves to nothing', () {
      expect(
        resolveSignInAccount(
          method: SignInMethod.phone,
          claims: {'name': 'Tenzin'},
        ),
        isNull,
      );
    });

    test('with no recorded method, shows whichever identifier exists', () {
      expect(
        resolveSignInAccount(method: null, email: 'tenzin@example.com'),
        const SignInAccount(method: null, identifier: 'tenzin@example.com'),
      );
      expect(
        resolveSignInAccount(
          method: null,
          claims: {'phone_number': '+66812345678'},
        ),
        const SignInAccount(method: null, identifier: '+66812345678'),
      );
    });
  });

  group('decodeJwtClaims', () {
    test('decodes the payload', () {
      expect(decodeJwtClaims(_jwt({'sub': 'u-1'})), {'sub': 'u-1'});
    });

    test('returns null for a malformed token', () {
      expect(decodeJwtClaims('not-a-jwt'), isNull);
      expect(decodeJwtClaims('a.b.c'), isNull);
    });
  });
}

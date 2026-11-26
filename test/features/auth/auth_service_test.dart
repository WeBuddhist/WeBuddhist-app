import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/auth/auth_service.dart';
import 'package:flutter_pecha/features/auth/data/session/auth_token_api.dart';
import 'package:flutter_pecha/features/auth/data/session/firebase_sign_in.dart';
import 'package:flutter_pecha/features/auth/data/session/legacy_auth0_cleanup.dart';
import 'package:flutter_pecha/features/auth/data/session/session_token_store.dart';
import 'package:flutter_pecha/features/auth/domain/entities/account_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An unsigned JWT that expires [expiresIn] from now.
String _jwt({Duration expiresIn = const Duration(hours: 1), String tag = ''}) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256'})}.${seg({'sub': 'u-1', 'exp': exp, 'tag': tag})}.sig';
}

class _Store implements SessionTokenStore {
  SessionTokens? tokens;
  Object? readError;
  int clears = 0;

  @override
  Future<SessionTokens?> read() async {
    if (readError != null) throw readError!;
    return tokens;
  }

  @override
  Future<void> write(SessionTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async {
    clears++;
    tokens = null;
  }
}

class _Api implements AuthTokenApi {
  /// Each exchange takes the next: tokens to return, an error to throw, or a
  /// `Completer<SessionTokens>` to hold the call open.
  final List<Object> exchangeResults = [];
  final List<({String token, String? first, String? last})> exchanges = [];

  /// Each refresh takes the next: an access token, an error, or a
  /// `Completer<String>` to hold the call open.
  final List<Object> refreshResults = [];
  final List<String> refreshes = [];

  @override
  Future<SessionTokens> exchangeFirebaseToken({
    required String firebaseToken,
    String? firstName,
    String? lastName,
  }) async {
    exchanges.add((token: firebaseToken, first: firstName, last: lastName));
    final result = exchangeResults.removeAt(0);
    if (result is SessionTokens) return result;
    if (result is Completer<SessionTokens>) return result.future;
    throw result;
  }

  @override
  Future<String> refreshAccessToken(String refreshToken) async {
    refreshes.add(refreshToken);
    final result = refreshResults.removeAt(0);
    if (result is String) return result;
    if (result is Completer<String>) return result.future;
    throw result;
  }
}

class _SignIn implements FirebaseSignIn {
  Object google = const FirebaseProof(
    idToken: 'firebase-google',
    firstName: 'Tenzin',
    lastName: 'Dolma',
  );
  Object apple = const FirebaseProof(idToken: 'firebase-apple');
  Object phoneStart = const PhoneVerificationCodeSent(
    verificationId: 'v-1',
    resendToken: 7,
  );
  Object smsCode = const FirebaseProof(idToken: 'firebase-phone');

  final List<String> verified = [];
  int? lastResendToken;
  int providerSignOuts = 0;

  Future<T> _answer<T>(Object value) async {
    if (value is T) return value as T;
    throw value;
  }

  @override
  Future<FirebaseProof> signInWithGoogle() => _answer(google);

  @override
  Future<FirebaseProof> signInWithApple() => _answer(apple);

  @override
  Future<PhoneVerificationStart> verifyPhoneNumber(
    String phoneNumber, {
    int? resendToken,
  }) {
    verified.add(phoneNumber);
    lastResendToken = resendToken;
    return _answer(phoneStart);
  }

  @override
  Future<FirebaseProof> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) => _answer(this.smsCode);

  @override
  Future<void> signOutProviders() async => providerSignOuts++;
}

class _Cleanup implements LegacyAuth0Cleanup {
  _Cleanup(this.removed);

  final bool removed;
  int runs = 0;

  @override
  Future<bool> run() async {
    runs++;
    return removed;
  }
}

Matcher _authException(String code) =>
    isA<AuthException>().having((e) => e.code, 'code', code);

void main() {
  late _Store store;
  late _Api api;
  late _SignIn signIn;
  late AuthService auth;

  AuthService build({bool legacyRemoved = false}) => AuthService.forTesting(
    store: store,
    api: api,
    signIn: signIn,
    legacyCleanup: _Cleanup(legacyRemoved),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    api = _Api();
    signIn = _SignIn();
    auth = build();
  });

  final session = SessionTokens(
    accessToken: _jwt(tag: 'first'),
    refreshToken: 'refresh-1',
  );

  group('sign-in', () {
    test('Google: exchanges the Firebase token and stores the session',
        () async {
      api.exchangeResults.add(session);

      final tokens = await auth.loginWithGoogle();

      expect(tokens.accessToken, session.accessToken);
      expect(store.tokens?.refreshToken, 'refresh-1');
      expect(api.exchanges.single, (
        token: 'firebase-google',
        first: 'Tenzin',
        last: 'Dolma',
      ));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.signInMethod), 'google');
    });

    test('Apple and phone record their own sign-in method', () async {
      api.exchangeResults.addAll([session, session]);
      final prefs = await SharedPreferences.getInstance();

      await auth.loginWithApple();
      expect(prefs.getString(StorageKeys.signInMethod), 'apple');

      await auth.loginWithPhoneCode(verificationId: 'v-1', smsCode: '123456');
      expect(prefs.getString(StorageKeys.signInMethod), 'phone');
      expect(api.exchanges.last.token, 'firebase-phone');
    });

    test('a cancelled sign-in stores nothing', () async {
      signIn.google = const FirebaseSignInException(
        FirebaseSignInException.cancelled,
      );

      await expectLater(
        auth.loginWithGoogle(),
        throwsA(_authException(AuthService.cancelledCode)),
      );
      expect(store.tokens, isNull);
      expect(api.exchanges, isEmpty);
    });

    test('a Firebase error keeps its code for the screen to word', () async {
      signIn.smsCode = const FirebaseSignInException(
        'invalid-verification-code',
      );

      await expectLater(
        auth.loginWithPhoneCode(verificationId: 'v-1', smsCode: '000000'),
        throwsA(_authException('invalid-verification-code')),
      );
    });

    test('a refused exchange reports its status, and offline is "network"',
        () async {
      api.exchangeResults.add(const AuthApiException(403, 'not verified'));
      await expectLater(
        auth.loginWithGoogle(),
        throwsA(_authException('http_403')),
      );

      api.exchangeResults.add(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        auth.loginWithGoogle(),
        throwsA(_authException('network')),
      );
      expect(store.tokens, isNull);
    });
  });

  group('a new account the provider shared no full name for', () {
    test('phone: created with the placeholder, without asking', () async {
      // The first exchange carries no name and is refused; the second is the
      // same Firebase token with the placeholder.
      api.exchangeResults.addAll([
        const ProfileNamesRequiredException(),
        session,
      ]);

      await auth.loginWithPhoneCode(verificationId: 'v-1', smsCode: '123456');

      expect(api.exchanges, [
        (token: 'firebase-phone', first: null, last: null),
        (
          token: 'firebase-phone',
          first: AccountNames.placeholder.first,
          last: AccountNames.placeholder.last,
        ),
      ]);
      expect(store.tokens?.accessToken, session.accessToken);
      final prefs = await SharedPreferences.getInstance();
      // What makes onboarding ask a phone account what to call it.
      expect(prefs.getString(StorageKeys.signInMethod), 'phone');
    });

    test('Google with a single name: that name stands for both', () async {
      signIn.google = const FirebaseProof(
        idToken: 'firebase-google',
        firstName: 'Tenzin',
      );
      api.exchangeResults.addAll([
        const ProfileNamesRequiredException(),
        session,
      ]);

      await auth.loginWithGoogle();

      expect(api.exchanges.last, (
        token: 'firebase-google',
        first: 'Tenzin',
        last: 'Tenzin',
      ));
      expect(store.tokens, isNotNull);
    });

    test('Apple withholding the name: the placeholder', () async {
      api.exchangeResults.addAll([
        const ProfileNamesRequiredException(),
        session,
      ]);

      await auth.loginWithApple();

      expect(api.exchanges.last.first, AccountNames.placeholder.first);
      expect(api.exchanges.last.last, AccountNames.placeholder.last);
    });

    test('an existing account is never sent a made-up name', () async {
      // Apple shares no name on a later sign-in. The account exists, so the
      // first exchange succeeds and nothing is filled in.
      api.exchangeResults.add(session);

      await auth.loginWithApple();

      expect(api.exchanges.single, (
        token: 'firebase-apple',
        first: null,
        last: null,
      ));
    });

    test('still refused with names filled in: a failure, not a loop', () async {
      api.exchangeResults.addAll([
        const ProfileNamesRequiredException(),
        const ProfileNamesRequiredException(),
      ]);

      await expectLater(
        auth.loginWithApple(),
        throwsA(_authException('http_422')),
      );
      expect(api.exchanges, hasLength(2));
      expect(store.tokens, isNull);
    });
  });

  group('a sign-in the person left', () {
    final other = SessionTokens(
      accessToken: _jwt(tag: 'other'),
      refreshToken: 'refresh-other',
    );

    test('an exchange that answers late does not replace a newer sign-in',
        () async {
      final pending = Completer<SessionTokens>();
      api.exchangeResults.add(pending);
      final first = auth.loginWithApple();
      await Future<void>.delayed(Duration.zero);

      // The person gives up on Apple and signs in with Google instead.
      api.exchangeResults.add(other);
      await auth.loginWithGoogle();
      pending.complete(session);

      await expectLater(
        first,
        throwsA(_authException(AuthService.cancelledCode)),
      );
      expect(store.tokens?.refreshToken, 'refresh-other');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.signInMethod), 'google');
    });

    test('nor is its retry with filled-in names sent', () async {
      final pending = Completer<SessionTokens>();
      api.exchangeResults.add(pending);
      final first = auth.loginWithApple();
      await Future<void>.delayed(Duration.zero);

      api.exchangeResults.add(other);
      await auth.loginWithGoogle();
      pending.completeError(const ProfileNamesRequiredException());

      await expectLater(
        first,
        throwsA(_authException(AuthService.cancelledCode)),
      );
      // Apple's first try and Google's: no third call for the abandoned one.
      expect(api.exchanges, hasLength(2));
    });

    test('signing out drops an exchange still on the wire', () async {
      final pending = Completer<SessionTokens>();
      api.exchangeResults.add(pending);
      final login = auth.loginWithGoogle();
      await Future<void>.delayed(Duration.zero);

      await auth.localLogout();
      pending.complete(session);

      await expectLater(login, throwsA(isA<AuthException>()));
      expect(store.tokens, isNull);
    });
  });

  group('phone', () {
    test('a sent code returns what the code step needs', () async {
      final start = await auth.requestPhoneCode('+919876543210');

      expect(start.verificationId, 'v-1');
      expect(start.resendToken, 7);
      expect(start.session, isNull);
      expect(signIn.verified, ['+919876543210']);
      expect(store.tokens, isNull);
    });

    test('a resend passes the token from the first request', () async {
      await auth.requestPhoneCode('+919876543210', resendToken: 7);
      expect(signIn.lastResendToken, 7);
    });

    test('a number Android verified without a code signs in at once',
        () async {
      signIn.phoneStart = const PhoneVerificationAutoVerified(
        FirebaseProof(idToken: 'firebase-auto'),
      );
      api.exchangeResults.add(session);

      final start = await auth.requestPhoneCode('+919876543210');

      expect(start.session?.accessToken, session.accessToken);
      expect(start.verificationId, isNull);
      expect(store.tokens, isNotNull);
    });

    test('Android reading the SMS signs in without a typed code', () async {
      final sms = Completer<FirebaseProof?>();
      signIn.phoneStart = PhoneVerificationCodeSent(
        verificationId: 'v-1',
        autoVerified: sms.future,
      );
      api.exchangeResults.add(session);

      final start = await auth.requestPhoneCode('+919876543210');
      expect(store.tokens, isNull);

      sms.complete(const FirebaseProof(idToken: 'firebase-auto'));
      final tokens = await start.autoSignIn;

      expect(tokens?.accessToken, session.accessToken);
      expect(store.tokens, isNotNull);
      expect(api.exchanges.single.token, 'firebase-auto');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.signInMethod), 'phone');
    });

    test('a code typed first wins: the late automatic sign-in is dropped',
        () async {
      final sms = Completer<FirebaseProof?>();
      signIn.phoneStart = PhoneVerificationCodeSent(
        verificationId: 'v-1',
        autoVerified: sms.future,
      );
      final start = await auth.requestPhoneCode('+919876543210');

      api.exchangeResults.add(session);
      await auth.loginWithPhoneCode(verificationId: 'v-1', smsCode: '123456');
      sms.complete(const FirebaseProof(idToken: 'firebase-auto'));

      expect(await start.autoSignIn, isNull);
      // Only the typed code's exchange was ever stored.
      expect(store.tokens?.accessToken, session.accessToken);
    });

    test('leaving the code screen drops a late automatic sign-in', () async {
      final sms = Completer<FirebaseProof?>();
      signIn.phoneStart = PhoneVerificationCodeSent(
        verificationId: 'v-1',
        autoVerified: sms.future,
      );
      final start = await auth.requestPhoneCode('+919876543210');

      // Left the screen, or went back to change the number.
      auth.cancelPhoneSignIn();
      api.exchangeResults.add(session);
      sms.complete(const FirebaseProof(idToken: 'firebase-auto'));

      expect(await start.autoSignIn, isNull);
      expect(store.tokens, isNull);
    });

    test('no SMS read (iOS, or the wait ran out): nothing happens', () async {
      signIn.phoneStart = PhoneVerificationCodeSent(
        verificationId: 'v-1',
        autoVerified: Future.value(),
      );

      final start = await auth.requestPhoneCode('+919876543210');

      expect(await start.autoSignIn, isNull);
      expect(api.exchanges, isEmpty);
    });

    test('an automatic sign-in the backend refuses leaves the code screen',
        () async {
      signIn.phoneStart = PhoneVerificationCodeSent(
        verificationId: 'v-1',
        autoVerified: Future.value(
          const FirebaseProof(idToken: 'firebase-auto'),
        ),
      );
      api.exchangeResults.add(const AuthApiException(503, null));

      final start = await auth.requestPhoneCode('+919876543210');

      expect(await start.autoSignIn, isNull);
      expect(store.tokens, isNull);
    });

    test('a number Firebase refuses reports why', () async {
      signIn.phoneStart = const FirebaseSignInException('invalid-phone-number');
      await expectLater(
        auth.requestPhoneCode('+1'),
        throwsA(_authException('invalid-phone-number')),
      );
    });
  });

  group('the API bearer', () {
    test('is the stored access token while it is fresh', () async {
      store.tokens = session;

      expect(await auth.getValidAccessToken(), session.accessToken);
      expect(api.refreshes, isEmpty);
    });

    test('is renewed ahead of the request when about to expire', () async {
      store.tokens = SessionTokens(
        accessToken: _jwt(expiresIn: const Duration(seconds: 30)),
        refreshToken: 'refresh-1',
      );
      final renewed = _jwt(tag: 'renewed');
      api.refreshResults.add(renewed);

      expect(await auth.getValidAccessToken(), renewed);
      expect(api.refreshes, ['refresh-1']);
      expect(store.tokens?.accessToken, renewed);
      // The backend does not renew the refresh token.
      expect(store.tokens?.refreshToken, 'refresh-1');
    });

    test('a forced refresh asks even while the token looks fresh', () async {
      store.tokens = session;
      final renewed = _jwt(tag: 'renewed');
      api.refreshResults.add(renewed);

      expect(await auth.forceRefreshAccessToken(), renewed);
      expect(api.refreshes, hasLength(1));
    });

    test('concurrent callers share one refresh', () async {
      store.tokens = session;
      final pending = Completer<String>();
      api.refreshResults.add(pending);

      final calls = [
        auth.forceRefreshAccessToken(),
        auth.forceRefreshAccessToken(),
        auth.forceRefreshAccessToken(),
      ];
      await Future<void>.delayed(Duration.zero);
      pending.complete(_jwt(tag: 'renewed'));
      final results = await Future.wait(calls);

      expect(api.refreshes, hasLength(1));
      expect(results.toSet(), hasLength(1));
    });

    test('with nothing stored there is no session', () async {
      await expectLater(
        auth.getValidAccessToken(),
        throwsA(_authException(AuthService.noSessionCode)),
      );
      await expectLater(
        auth.forceRefreshAccessToken(),
        throwsA(_authException(AuthService.noSessionCode)),
      );
      expect(api.refreshes, isEmpty);
    });
  });

  group('a refresh that fails', () {
    setUp(() => store.tokens = session);

    test('401 ends the session: tokens cleared, never asked again', () async {
      api.refreshResults.add(const AuthApiException(401, 'Refresh token expired'));

      Object? error;
      try {
        await auth.forceRefreshAccessToken();
      } catch (e) {
        error = e;
      }

      expect(error, _authException(AuthService.refreshRejectedCode));
      expect(AuthService.isSessionPermanentlyLost(error!), isTrue);
      expect(store.tokens, isNull);

      // Later requests fail fast instead of sending the dead token again.
      await expectLater(
        auth.getValidAccessToken(),
        throwsA(_authException(AuthService.noSessionCode)),
      );
      expect(api.refreshes, hasLength(1));
    });

    test('another 4xx is a refusal, and keeps the tokens', () async {
      api.refreshResults.add(const AuthApiException(404, 'Not Found'));

      Object? error;
      try {
        await auth.forceRefreshAccessToken();
      } catch (e) {
        error = e;
      }

      expect(error, _authException(AuthService.refreshRefusedCode));
      expect(AuthService.isSessionPermanentlyLost(error!), isFalse);
      expect(AuthService.isTokenRenewalFailed(error), isTrue);
      expect(store.tokens, isNotNull);
    });

    test('a 5xx or no connection keeps the session', () async {
      api.refreshResults.add(const AuthApiException(503, null));
      Object? error;
      try {
        await auth.forceRefreshAccessToken();
      } catch (e) {
        error = e;
      }
      expect(AuthService.isSessionPermanentlyLost(error!), isFalse);
      expect(AuthService.isTokenRenewalFailed(error), isFalse);

      api.refreshResults.add(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      try {
        await auth.forceRefreshAccessToken();
      } catch (e) {
        error = e;
      }
      expect(AuthService.isSessionPermanentlyLost(error), isFalse);
      expect(AuthService.isTokenRenewalFailed(error), isFalse);
      expect(store.tokens?.accessToken, session.accessToken);
    });

    test('a 401 that lands after a new sign-in leaves the new session alone',
        () async {
      final pending = Completer<String>();
      api.refreshResults.add(pending);
      final refresh = auth.forceRefreshAccessToken();
      await Future<void>.delayed(Duration.zero);

      final next = SessionTokens(
        accessToken: _jwt(tag: 'next'),
        refreshToken: 'refresh-2',
      );
      api.exchangeResults.add(next);
      await auth.loginWithGoogle();

      pending.completeError(const AuthApiException(401, 'expired'));
      final error = await refresh.then<Object?>((_) => null, onError: (e) => e);

      expect(error, isA<AuthException>());
      // Not a terminal code: the 401 path signs out on those, which would
      // end the new session.
      expect(AuthService.isSessionPermanentlyLost(error!), isFalse);
      expect(AuthService.isTokenRenewalFailed(error), isFalse);
      expect(store.tokens?.refreshToken, 'refresh-2');
      expect(store.clears, 0);
    });

    test('a refusal that lands after a new sign-in does not end it', () async {
      final pending = Completer<String>();
      api.refreshResults.add(pending);
      final refresh = auth.forceRefreshAccessToken();
      await Future<void>.delayed(Duration.zero);

      api.exchangeResults.add(
        SessionTokens(accessToken: _jwt(tag: 'next'), refreshToken: 'refresh-2'),
      );
      await auth.loginWithGoogle();

      pending.completeError(const AuthApiException(403, 'refused'));
      final error = await refresh.then<Object?>((_) => null, onError: (e) => e);

      expect(error, isA<AuthException>());
      expect(AuthService.isSessionPermanentlyLost(error!), isFalse);
      expect(AuthService.isTokenRenewalFailed(error), isFalse);
      expect(store.tokens?.refreshToken, 'refresh-2');
    });

    test('a token that arrives after sign-out is not stored', () async {
      final pending = Completer<String>();
      api.refreshResults.add(pending);
      final refresh = auth.forceRefreshAccessToken();
      await Future<void>.delayed(Duration.zero);

      await auth.localLogout();
      pending.complete(_jwt(tag: 'late'));

      await expectLater(refresh, throwsA(isA<AuthException>()));
      expect(store.tokens, isNull);
    });
  });

  group('the stored session', () {
    test('hasValidCredentials follows the store', () async {
      expect(await auth.hasValidCredentials(), isFalse);
      store.tokens = session;
      expect(await auth.hasValidCredentials(), isTrue);
    });

    test('a store that cannot be read is "no" without ending anything',
        () async {
      store.tokens = session;
      store.readError = StateError('keystore locked');

      expect(await auth.hasValidCredentials(), isFalse);
      expect(store.clears, 0);
    });

    test('getCredentials renews an expiring access token first', () async {
      store.tokens = SessionTokens(
        accessToken: _jwt(expiresIn: const Duration(seconds: 10)),
        refreshToken: 'refresh-1',
      );
      final renewed = _jwt(tag: 'renewed');
      api.refreshResults.add(renewed);

      final tokens = await auth.getCredentials();

      expect(tokens.accessToken, renewed);
      expect(tokens.refreshToken, 'refresh-1');
    });

    test('logout clears the tokens and every identity marker', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.currentUserId: 'u-1',
        StorageKeys.userData: '{}',
        StorageKeys.signInMethod: 'google',
        'is_guest_mode': true,
      });
      store.tokens = session;

      await auth.localLogout();

      expect(store.tokens, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.currentUserId), isNull);
      expect(prefs.getString(StorageKeys.userData), isNull);
      expect(prefs.getString(StorageKeys.signInMethod), isNull);
      expect(prefs.getBool('is_guest_mode'), isNull);
      expect(signIn.providerSignOuts, 1);
    });

    test('the method last used on this phone survives signing out', () async {
      api.exchangeResults.add(session);
      await auth.loginWithGoogle();

      await auth.localLogout();

      // What marks the "Last used" button the next time.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.lastSignInMethod), 'google');
      expect(prefs.getString(StorageKeys.signInMethod), isNull);
    });
  });

  group('initialize', () {
    test('reports a removed Auth0 session once', () async {
      auth = build(legacyRemoved: true);

      await auth.initialize();
      await auth.initialize();

      expect(auth.takeLegacySessionRemoved(), isTrue);
      expect(auth.takeLegacySessionRemoved(), isFalse);
    });

    test('reports nothing on a phone that had no Auth0 session', () async {
      await auth.initialize();
      expect(auth.takeLegacySessionRemoved(), isFalse);
    });
  });
}

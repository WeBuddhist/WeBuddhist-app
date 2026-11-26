import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/env.dart';
import 'package:flutter_pecha/features/auth/data/session/auth_token_api.dart';
import 'package:flutter_pecha/features/auth/data/session/firebase_sign_in.dart';
import 'package:flutter_pecha/features/auth/data/session/legacy_auth0_cleanup.dart';
import 'package:flutter_pecha/features/auth/data/session/session_token_store.dart';
import 'package:flutter_pecha/features/auth/domain/entities/account_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sign-in and the session.
///
/// Firebase Authentication (Google, Apple, phone) proves who the person is.
/// Its ID token is exchanged at `POST /auth/firebase/exchange` for the
/// backend's own access and refresh tokens, and those are the session from
/// then on: the access token is the API bearer, and the refresh token gets a
/// new one from `POST /auth/refresh-token`. Firebase is not asked again until
/// the next sign-in.
class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  /// A separate instance wired to fakes.
  @visibleForTesting
  AuthService.forTesting({
    required SessionTokenStore store,
    required AuthTokenApi api,
    required FirebaseSignIn signIn,
    LegacyAuth0Cleanup? legacyCleanup,
  }) : _store = store,
       _api = api,
       _signIn = signIn,
       _legacyCleanup = legacyCleanup;

  final _logger = AppLogger('AuthService');

  SessionTokenStore? _store;
  AuthTokenApi? _api;
  FirebaseSignIn? _signIn;
  LegacyAuth0Cleanup? _legacyCleanup;

  bool _isInitialized = false;

  /// Minimum lifetime (seconds) an access token must have left before it is
  /// renewed ahead of a request. Matches the buffer in [isJwtExpired].
  static const int _kMinTokenTtlSeconds = 120;

  /// Ceiling for one refresh call.
  static const Duration _kRefreshTimeout = Duration(seconds: 20);

  // SharedPreferences key for guest mode
  static const String _guestModeKey = 'is_guest_mode';

  /// Sign-in methods, as stored under [StorageKeys.signInMethod] and sent to
  /// analytics.
  static const String methodGoogle = 'google';
  static const String methodApple = 'apple';
  static const String methodPhone = 'phone';

  /// [AuthException.code]: nothing is stored, so there is no session.
  static const String noSessionCode = 'no_session';

  /// [AuthException.code]: the backend answered 401 to the refresh token
  /// (expired, revoked, or the account is gone). The session is over.
  static const String refreshRejectedCode = 'refresh_rejected';

  /// [AuthException.code]: the backend refused the refresh with another 4xx.
  /// Terminal only where we know we are online, see [isTokenRenewalFailed].
  static const String refreshRefusedCode = 'refresh_refused';

  /// [AuthException.code]: the person closed the sign-in sheet.
  static const String cancelledCode = 'cancelled';

  /// One refresh at a time: every caller shares the call in flight.
  Future<String>? _inflightRefresh;

  /// Bumped on every login and logout, so a refresh that began under one
  /// session can neither store its token in the next nor clear it.
  int _sessionGeneration = 0;

  /// Bumped when a sign-in starts or the session ends. An exchange that
  /// answers under another value belongs to an attempt the person has left
  /// (started another sign-in, signed out), and is dropped instead of
  /// becoming the session.
  int _loginAttempt = 0;

  /// True once, after [initialize] removed an Auth0 session from an earlier
  /// build. See [takeLegacySessionRemoved].
  bool _legacySessionRemoved = false;

  /// In-flight [initialize], shared so concurrent callers run it once.
  Future<void>? _initializing;

  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initializing ??= _doInitialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _doInitialize() async {
    // Before anything reads the session, so an old Auth0 login is gone.
    _legacySessionRemoved =
        await (_legacyCleanup ??= LegacyAuth0CleanupImpl()).run();
    _isInitialized = true;
  }

  // Built on first use rather than in [initialize]: a sign-out can run before
  // it (the Android fresh-install clear) and must still reach the store.
  SessionTokenStore get _tokens => _store ??= SecureSessionTokenStore();

  FirebaseSignIn get _firebase => _signIn ??= FirebaseSignInImpl();

  AuthTokenApi get _tokenApi =>
      _api ??= AuthTokenApi(
        Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ),
      );

  /// Whether [initialize] signed out an Auth0 session left by an earlier
  /// build. Reads true once, so the caller can drop that account's identity.
  bool takeLegacySessionRemoved() {
    final removed = _legacySessionRemoved;
    _legacySessionRemoved = false;
    return removed;
  }

  // ========== Sign-in ==========

  Future<SessionTokens> loginWithGoogle() =>
      _login(methodGoogle, () => _firebase.signInWithGoogle());

  Future<SessionTokens> loginWithApple() =>
      _login(methodApple, () => _firebase.signInWithApple());

  /// Sends an SMS code to [phoneNumber] (E.164). Returns how to continue, or
  /// the session when Android verified the number without a code.
  Future<PhoneLoginStart> requestPhoneCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    try {
      await initialize();
      final attempt = ++_loginAttempt;
      final start = await _firebase.verifyPhoneNumber(
        phoneNumber,
        resendToken: resendToken,
      );
      switch (start) {
        case PhoneVerificationCodeSent():
          return PhoneLoginStart.codeSent(
            verificationId: start.verificationId,
            resendToken: start.resendToken,
            autoSignIn: _autoSignIn(start.autoVerified, attempt),
          );
        case PhoneVerificationAutoVerified():
          return PhoneLoginStart.signedIn(
            await _exchange(methodPhone, start.proof, attempt: attempt),
          );
      }
    } catch (e) {
      throw _loginFailure(methodPhone, e);
    }
  }

  /// Android can read the SMS code itself. When it does, finish the sign-in
  /// without the person typing anything. Completes with null when that did
  /// not happen, or when the person got there first by typing the code (the
  /// attempt has moved on) or left.
  Future<SessionTokens?> _autoSignIn(
    Future<FirebaseProof?>? autoVerified,
    int attempt,
  ) async {
    if (autoVerified == null) return null;
    final proof = await autoVerified;
    if (proof == null) return null;
    try {
      return await _exchange(methodPhone, proof, attempt: attempt);
    } catch (e) {
      _logger.warning('Automatic phone sign-in did not finish: $e');
      return null;
    }
  }

  /// The person left the code screen, or went back to change the number.
  /// An automatic sign-in Android may still finish for that attempt is
  /// dropped: they chose not to go on with it.
  void cancelPhoneSignIn() => _loginAttempt++;

  /// Finishes a phone sign-in with the code from the SMS.
  Future<SessionTokens> loginWithPhoneCode({
    required String verificationId,
    required String smsCode,
  }) => _login(
    methodPhone,
    () => _firebase.signInWithSmsCode(
      verificationId: verificationId,
      smsCode: smsCode,
    ),
  );

  Future<SessionTokens> _login(
    String method,
    Future<FirebaseProof> Function() signIn,
  ) async {
    try {
      await initialize();
      final attempt = ++_loginAttempt;
      final proof = await signIn();
      return await _exchange(method, proof, attempt: attempt);
    } catch (e) {
      throw _loginFailure(method, e);
    }
  }

  Future<SessionTokens> _exchange(
    String method,
    FirebaseProof proof, {
    required int attempt,
  }) async {
    SessionTokens tokens;
    try {
      tokens = await _tokenApi.exchangeFirebaseToken(
        firebaseToken: proof.idToken,
        firstName: proof.firstName,
        lastName: proof.lastName,
      );
    } on ProfileNamesRequiredException {
      // A new account, and the provider did not share a first and last name
      // (phone never does). Nobody is asked for one mid sign-in: the missing
      // part is filled in, and the account's owner names it afterwards, in
      // onboarding or Edit profile.
      //
      // Only on this second try: an existing account must not be handed a
      // made-up name the backend might act on.
      _throwIfLeft(attempt);
      final names = AccountNames.complete(proof.firstName, proof.lastName);
      tokens = await _tokenApi.exchangeFirebaseToken(
        firebaseToken: proof.idToken,
        firstName: names.first,
        lastName: names.last,
      );
    }
    _throwIfLeft(attempt);
    // Start the new session *before* storing it, so a refresh that began
    // under the old one cannot overwrite or clear the tokens saved here.
    _sessionGeneration++;
    await _tokens.write(tokens);
    await _saveSignInMethod(method);
    _logger.info('Signed in with $method; session tokens stored');
    return tokens;
  }

  /// The exchange answered for an attempt the person has already left.
  void _throwIfLeft(int attempt) {
    if (attempt == _loginAttempt) return;
    throw AuthException('Login was cancelled by user', code: cancelledCode);
  }

  /// Shown in Settings ("Signed in with Google"). The backend's tokens do not
  /// say which provider was used, so it is remembered here.
  Future<void> _saveSignInMethod(String method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.signInMethod, method);
      // Outlives sign-out: marks the "Last used" button next time.
      await prefs.setString(StorageKeys.lastSignInMethod, method);
    } catch (e) {
      _logger.warning('Failed to remember the sign-in method: $e');
    }
  }

  /// One readable [AuthException] per failure. The text reaches analytics as
  /// `reason_detail`, so it names the cause and carries no token or number.
  AuthException _loginFailure(String method, Object error) {
    if (error is AuthException) return error;
    if (error is FirebaseSignInException) {
      if (error.isCancelled) {
        _logger.info('Sign-in with $method was cancelled by user');
        return AuthException('Login was cancelled by user', code: cancelledCode);
      }
      _logger.warning('Firebase sign-in with $method failed: ${error.code}');
      if (error.code == FirebaseSignInException.notConfigured) {
        return AuthException('Login is not configured', code: error.code);
      }
      return AuthException('Sign-in failed (${error.code})', code: error.code);
    }
    if (error is ProfileNamesRequiredException) {
      // Refused again with names filled in: nothing more the app can add.
      _logger.warning('Exchange for $method still asks for names');
      return AuthException(
        'Sign-in was refused (HTTP 422)',
        code: 'http_422',
      );
    }
    if (error is AuthApiException) {
      _logger.warning('Exchange for $method failed: $error');
      return AuthException(
        'Sign-in was refused (HTTP ${error.statusCode})',
        code: 'http_${error.statusCode}',
      );
    }
    if (error is DioException ||
        error is SocketException ||
        error is TimeoutException) {
      _logger.warning('Network error during $method sign-in: $error');
      return AuthException('Network error during login', code: 'network');
    }
    _logger.error('Unexpected login error for $method', error);
    return AuthException('An unexpected error occurred during login');
  }

  // ========== Session ==========

  /// The stored session, with the access token renewed first when it is
  /// about to expire. Throws an [AuthException] the callers classify with
  /// [isSessionPermanentlyLost]; anything else is a failure worth retrying.
  Future<SessionTokens> getCredentials() async {
    final tokens = await _readSession();
    if (!isJwtExpired(tokens.accessToken)) return tokens;
    final accessToken = await _refresh();
    return tokens.withAccessToken(accessToken);
  }

  /// API bearer, renewed ahead of the request when within
  /// [_kMinTokenTtlSeconds] of expiry.
  Future<String?> getValidAccessToken() async {
    final tokens = await _readSession();
    if (!isJwtExpired(tokens.accessToken)) return tokens.accessToken;
    return _refresh();
  }

  /// Reactive 401 path: the server refused the current access token, so get
  /// a new one whatever its expiry says.
  Future<String?> forceRefreshAccessToken() => _refresh();

  Future<SessionTokens> _readSession() async {
    final tokens = await _tokens.read();
    if (tokens == null) {
      throw AuthException('No session', code: noSessionCode);
    }
    return tokens;
  }

  /// All concurrent callers (the request path and the 401 path, across every
  /// Dio client) share one call.
  Future<String> _refresh() {
    final inflight = _inflightRefresh;
    if (inflight != null) return inflight;
    late final Future<String> tracked;
    tracked = _runRefresh().whenComplete(() {
      if (identical(_inflightRefresh, tracked)) _inflightRefresh = null;
    });
    _inflightRefresh = tracked;
    return tracked;
  }

  Future<String> _runRefresh() async {
    final generation = _sessionGeneration;
    final tokens = await _readSession();
    final String accessToken;
    try {
      accessToken = await _tokenApi
          .refreshAccessToken(tokens.refreshToken)
          .timeout(_kRefreshTimeout);
    } on AuthApiException catch (e) {
      // The person signed out or in again while this was on the wire, so the
      // answer is about a session that has ended. Reported as rejected or
      // refused, it would end the new one too: the reactive 401 path signs
      // out on those codes.
      if (generation != _sessionGeneration) {
        throw AuthException('Session changed during refresh');
      }
      if (e.statusCode == 401) {
        // Asking again can never succeed. Remove the dead tokens so later
        // calls and launches see "no session" without another round trip.
        _logger.warning(
          'The backend rejected the refresh token — clearing the session '
          'and requiring sign-in',
        );
        try {
          await _tokens.clear();
        } catch (clearError) {
          _logger.warning('Failed to clear rejected tokens: $clearError');
        }
        throw AuthException(
          'Refresh token rejected: ${e.detail ?? ''}',
          code: refreshRejectedCode,
        );
      }
      if (e.statusCode >= 400 && e.statusCode < 500) {
        throw AuthException(
          'Refresh refused (HTTP ${e.statusCode})',
          code: refreshRefusedCode,
        );
      }
      rethrow; // 5xx: the backend is unwell, the session is not.
    }
    // The person signed out or in again while this was on the wire.
    if (generation != _sessionGeneration) {
      throw AuthException('Session changed during refresh');
    }
    await _tokens.write(tokens.withAccessToken(accessToken));
    return accessToken;
  }

  /// Whether a session is stored.
  ///
  /// A `false` result is INDETERMINATE, not proof the session is gone: a
  /// keystore read that failed also collapses to `false`. Never use `false`
  /// here as grounds for logging the user out — terminal decisions need the
  /// typed errors from an actual refresh (see [isSessionPermanentlyLost]).
  Future<bool> hasValidCredentials() async {
    try {
      return await _tokens.read().timeout(const Duration(seconds: 10)) != null;
    } on TimeoutException {
      // Indeterminate: let getCredentials() make the terminal call.
      _logger.warning('Session check timed out — assuming a session');
      return true;
    } catch (e) {
      _logger.warning('Error checking the stored session: $e');
      return false;
    }
  }

  /// Signs out on this device: the tokens and every local identity marker.
  /// The backend has no session to end; its tokens simply stop being used.
  Future<void> localLogout() async {
    _sessionGeneration++;
    // Disowns an exchange still on the wire: its answer signs no one in.
    _loginAttempt++;
    try {
      await _tokens.clear();
    } catch (e) {
      _logger.error('Failed to clear session tokens', e);
    }
    // Only where a sign-in ran: building it here would start the Google SDK
    // on a phone that never used it.
    unawaited(_signIn?.signOutProviders());
    await _clearLocalIdentity();
    _logger.info('Local logout successful');
  }

  /// Clears every local identity marker so a later login can't read stale
  /// identity.
  Future<void> _clearLocalIdentity() async {
    await clearGuestMode();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.currentUserId);
      await prefs.remove(StorageKeys.userData);
      await prefs.remove(StorageKeys.signInMethod);
    } catch (e) {
      _logger.warning('Failed to clear local identity markers: $e');
    }
  }

  // ========== JWT helpers ==========

  /// Decode a JWT and report whether it is expired (or within [bufferSeconds]
  /// of expiry). Returns true on any parse failure (treat as expired).
  bool isJwtExpired(String jwt, {int bufferSeconds = _kMinTokenTtlSeconds}) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true;

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final exp = (claims['exp'] as num?)?.toInt();
      if (exp == null) return true;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

      return DateTime.now().isAfter(
        expiryDate.subtract(Duration(seconds: bufferSeconds)),
      );
    } catch (e) {
      _logger.warning('Failed to parse jwt exp: $e');
      return true;
    }
  }

  /// Seconds of remaining lifetime for [jwt]; 0 if expired/unparseable.
  int jwtRemainingTtlSeconds(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return 0;

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final exp = (claims['exp'] as num?)?.toInt();
      if (exp == null) return 0;
      final secs = exp - (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      return secs > 0 ? secs : 0;
    } catch (_) {
      return 0;
    }
  }

  // ========== Failure classification ==========

  /// Whether [error] from a session call means the session is truly gone and
  /// the user must sign in again — as opposed to a transient/offline failure
  /// we should tolerate (keep the user signed in and renew later).
  ///
  /// Permanent: nothing stored, or a refresh token the backend answered 401
  /// to. Offline, timeouts and 5xx stay transient: at app open they are
  /// usually a connectivity problem, and wiping a valid session for that
  /// would be a bug.
  static bool isSessionPermanentlyLost(Object error) =>
      error is AuthException &&
      (error.code == noSessionCode || error.code == refreshRejectedCode);

  /// Whether [error] is a refresh the backend *refused* (any 4xx).
  ///
  /// Deliberately wider than [isSessionPermanentlyLost]: in the reactive 401
  /// path the server just answered us, so we are provably online and talking
  /// to the right backend — a refusal there means the refresh token cannot
  /// be used, and the session must end instead of looping 401s forever.
  static bool isTokenRenewalFailed(Object error) =>
      error is AuthException &&
      (error.code == refreshRejectedCode || error.code == refreshRefusedCode);

  // ========== Guest mode ==========

  /// Save guest mode preference to SharedPreferences
  Future<void> saveGuestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestModeKey, true);
      _logger.info('Guest mode saved to preferences');
    } catch (e) {
      _logger.warning('Failed to save guest mode: $e');
    }
  }

  /// Check if user previously chose guest mode
  Future<bool> isGuestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool(_guestModeKey) ?? false;
      return isGuest;
    } catch (e) {
      _logger.warning('Failed to check guest mode: $e');
      return false;
    }
  }

  /// Clear guest mode state (called when user logs in or logs out)
  Future<void> clearGuestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestModeKey);
      _logger.info('Guest mode cleared from preferences');
    } catch (e) {
      _logger.warning('Failed to clear guest mode: $e');
    }
  }

  /// Continue as guest mode
  Future<void> continueAsGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestModeKey, true);
      _logger.info('Guest mode saved to preferences');
    } catch (e) {
      _logger.warning('Failed to save guest mode: $e');
    }
  }
}

/// How a phone sign-in continues after the number was submitted.
class PhoneLoginStart {
  const PhoneLoginStart.codeSent({
    required String this.verificationId,
    this.resendToken,
    this.autoSignIn,
  }) : session = null;

  const PhoneLoginStart.signedIn(SessionTokens this.session)
    : verificationId = null,
      resendToken = null,
      autoSignIn = null;

  /// Set when an SMS code went out.
  final String? verificationId;
  final int? resendToken;

  /// Set when the number was verified without a code (Android).
  final SessionTokens? session;

  /// After a code went out: completes with the session if Android reads the
  /// SMS and signs in by itself, with null if it does not.
  final Future<SessionTokens?>? autoSignIn;
}

class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message';
}

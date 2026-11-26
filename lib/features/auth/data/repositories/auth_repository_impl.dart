import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_pecha/core/error/exception_mapper.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/data/datasource/auth_remote_datasource.dart';
import 'package:flutter_pecha/features/auth/data/session/session_token_store.dart';
import 'package:flutter_pecha/features/auth/domain/entities/auth_credentials.dart';
import 'package:flutter_pecha/features/auth/domain/entities/phone_code_start.dart';
import 'package:flutter_pecha/features/auth/domain/entities/user.dart';
import 'package:flutter_pecha/features/auth/domain/entities/username_update_result.dart';
import 'package:flutter_pecha/features/auth/domain/failures/login_failure.dart';
import 'package:flutter_pecha/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_pecha/features/auth/auth_service.dart';

/// Auth repository implementation (Data Layer)
///
/// Wraps [AuthService]: turns its session tokens into domain
/// [AuthCredentials] and its exceptions into [Failure]s.
class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl({
    required AuthService authService,
    required AuthRemoteDataSource remoteDataSource,
  }) : _authService = authService,
       _remoteDataSource = remoteDataSource;

  AuthCredentials _toAuthCredentials(SessionTokens tokens) {
    final expiresIn = _authService.jwtRemainingTtlSeconds(tokens.accessToken);
    return AuthCredentials(
      accessToken: tokens.accessToken,
      tokenType: 'Bearer',
      expiresIn: expiresIn,
      obtainedAt: DateTime.now(),
      refreshToken: tokens.refreshToken,
      scope: null,
    );
  }

  // ========== Initialization ==========

  @override
  Future<Either<Failure, void>> initialize() async {
    try {
      await _authService.initialize();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to initialize auth: $e'));
    }
  }

  @override
  bool takeLegacySessionRemoved() => _authService.takeLegacySessionRemoved();

  // ========== Authentication Operations ==========

  @override
  Future<Either<Failure, AuthCredentials>> loginWithGoogle() =>
      _login('Google', _authService.loginWithGoogle);

  @override
  Future<Either<Failure, AuthCredentials>> loginWithApple() =>
      _login('Apple', _authService.loginWithApple);

  @override
  Future<Either<Failure, PhoneCodeStart>> requestPhoneCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    try {
      final start = await _authService.requestPhoneCode(
        phoneNumber,
        resendToken: resendToken,
      );
      final session = start.session;
      if (session != null) {
        return Right(PhoneCodeStart.signedIn(_toAuthCredentials(session)));
      }
      return Right(
        PhoneCodeStart.codeSent(
          verificationId: start.verificationId!,
          resendToken: start.resendToken,
          autoSignIn: start.autoSignIn?.then(
            (tokens) => tokens == null ? null : _toAuthCredentials(tokens),
          ),
        ),
      );
    } catch (e) {
      return Left(_loginFailure('Phone', e));
    }
  }

  @override
  void cancelPhoneSignIn() => _authService.cancelPhoneSignIn();

  @override
  Future<Either<Failure, AuthCredentials>> loginWithPhoneCode({
    required String verificationId,
    required String smsCode,
  }) => _login(
    'Phone',
    () => _authService.loginWithPhoneCode(
      verificationId: verificationId,
      smsCode: smsCode,
    ),
  );

  Future<Either<Failure, AuthCredentials>> _login(
    String provider,
    Future<SessionTokens> Function() signIn,
  ) async {
    try {
      return Right(_toAuthCredentials(await signIn()));
    } catch (e) {
      return Left(_loginFailure(provider, e));
    }
  }

  /// The message keeps the `<Provider> login failed: ` wrapper that auth
  /// analytics strips; the reason is what the screens read.
  LoginFailure _loginFailure(String provider, Object error) {
    return LoginFailure(
      '$provider login failed: $error',
      loginFailureReasonFor(error),
    );
  }

  @override
  Future<Either<Failure, void>> localLogout() async {
    try {
      await _authService.localLogout();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Logout failed: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> hasValidCredentials() async {
    try {
      final hasCredentials = await _authService.hasValidCredentials();
      return Right(hasCredentials);
    } catch (e) {
      return Left(UnknownFailure('Failed to check credentials: $e'));
    }
  }

  @override
  Future<Either<Failure, AuthCredentials>> getCredentials() async {
    try {
      final tokens = await _authService.getCredentials();
      return Right(_toAuthCredentials(tokens));
    } catch (e) {
      return Left(_credentialFailure(e, 'Failed to get credentials'));
    }
  }

  /// Maps a session error to a [Failure], distinguishing a permanently-lost
  /// session ([AuthenticationFailure] → re-login) from a transient/offline
  /// refresh failure ([NetworkFailure] → keep the session and retry). See
  /// [AuthService.isSessionPermanentlyLost].
  Failure _credentialFailure(Object error, String context) {
    return AuthService.isSessionPermanentlyLost(error)
        ? AuthenticationFailure('$context: $error')
        : NetworkFailure('$context: $error');
  }

  @override
  Future<Either<Failure, String>> getValidAccessToken() async {
    try {
      final accessToken = await _authService.getValidAccessToken();
      if (accessToken == null) {
        return const Left(AuthenticationFailure('No valid access token'));
      }
      return Right(accessToken);
    } catch (e) {
      return Left(_credentialFailure(e, 'Failed to get valid access token'));
    }
  }

  @override
  Future<Either<Failure, String>> forceRefreshAccessToken() async {
    try {
      final accessToken = await _authService.forceRefreshAccessToken();
      if (accessToken == null) {
        return const Left(
          AuthenticationFailure('Failed to refresh access token'),
        );
      }
      return Right(accessToken);
    } catch (e) {
      return Left(_credentialFailure(e, 'Failed to refresh access token'));
    }
  }

  // ========== Guest Mode Operations ==========

  @override
  Future<Either<Failure, void>> continueAsGuest() async {
    try {
      await _authService.continueAsGuest();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to continue as guest: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isGuestMode() async {
    try {
      final isGuest = await _authService.isGuestMode();
      return Right(isGuest);
    } catch (e) {
      return Left(UnknownFailure('Failed to check guest mode: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearGuestMode() async {
    try {
      await _authService.clearGuestMode();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to clear guest mode: $e'));
    }
  }

  // ========== User Data Operations ==========

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    // The bearer (access) token is attached by AuthInterceptor for protected
    // routes — no manual token prefetch needed here.
    try {
      final userModel = await _remoteDataSource.getCurrentUser();
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'getCurrentUser'));
    }
  }

  @override
  Future<Either<Failure, User>> updateUserInfo({
    String? firstName,
    String? lastName,
    String? displayName,
    String? title,
    String? organization,
    String? location,
    String? aboutMe,
    String? avatarUrl,
    List<String>? educations,
    List<Map<String, String>>? socialProfiles,
  }) async {
    final body = <String, dynamic>{
      if (firstName != null) 'firstname': firstName,
      if (lastName != null) 'lastname': lastName,
      if (displayName != null) 'display_name': displayName,
      if (title != null) 'title': title,
      if (organization != null) 'organization': organization,
      if (location != null) 'location': location,
      if (aboutMe != null) 'about_me': aboutMe,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'educations': educations ?? [],
      'social_profiles': socialProfiles ?? [],
    };

    try {
      final userModel = await _remoteDataSource.updateUserInfo(body);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'updateUserInfo'));
    }
  }

  @override
  Future<Either<Failure, UsernameUpdateResult>> updateUsername(
    String username,
  ) async {
    try {
      final result = await _remoteDataSource.updateUsername(username);
      return Right(result);
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'updateUsername'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(File file) async {
    try {
      final url = await _remoteDataSource.uploadAvatar(file);
      return Right(url);
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'uploadAvatar'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await _remoteDataSource.deleteUser();
      return const Right(null);
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'deleteAccount'));
    }
  }
}

/// The [LoginFailureReason] for what a sign-in threw. [AuthException.code]
/// is one of [AuthService]'s own codes, a Firebase Authentication error code
/// or `http_<status>` from the exchange.
LoginFailureReason loginFailureReasonFor(Object error) {
  final code = error is AuthException ? error.code : null;
  return switch (code) {
    AuthService.cancelledCode => LoginFailureReason.cancelled,
    'invalid-phone-number' ||
    'missing-phone-number' => LoginFailureReason.invalidPhoneNumber,
    'invalid-verification-code' ||
    'missing-verification-code' => LoginFailureReason.invalidCode,
    'session-expired' ||
    'code-expired' ||
    'invalid-verification-id' => LoginFailureReason.codeExpired,
    'too-many-requests' ||
    'quota-exceeded' => LoginFailureReason.tooManyRequests,
    'network' || 'network-request-failed' => LoginFailureReason.network,
    // The exchange answers 403 only for an email the provider has not
    // verified.
    'http_403' => LoginFailureReason.emailNotVerified,
    'not-configured' => LoginFailureReason.notConfigured,
    _ => LoginFailureReason.unknown,
  };
}

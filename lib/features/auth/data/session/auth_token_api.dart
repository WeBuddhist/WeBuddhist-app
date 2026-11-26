import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/auth/data/session/session_token_store.dart';

/// The backend answered a token call with an error status.
class AuthApiException implements Exception {
  const AuthApiException(this.statusCode, this.detail);

  final int statusCode;

  /// FastAPI's `detail` when it is text.
  final String? detail;

  @override
  String toString() => 'AuthApiException($statusCode): ${detail ?? ''}';
}

/// The exchange refused a new account because it has no first and last name
/// yet. Resend the same Firebase token with both.
class ProfileNamesRequiredException implements Exception {
  const ProfileNamesRequiredException();

  @override
  String toString() => 'ProfileNamesRequiredException';
}

/// The two backend calls that mint session tokens. They run on a Dio without
/// the auth and retry interceptors: a 401 here is an answer, not a reason to
/// refresh.
class AuthTokenApi {
  AuthTokenApi(this._dio);

  static const exchangePath = '/auth/firebase/exchange';
  static const refreshPath = '/auth/refresh-token';

  /// 422 detail for a new account without names: Google and Apple sign-ins
  /// get the first, phone sign-ins the second.
  static const _namesRequiredDetails = {
    'first name and last name are required for a new profile',
    'first name and last name are required for a new phone profile',
  };

  final Dio _dio;

  /// Swaps a fresh Firebase ID token for the backend's tokens.
  Future<SessionTokens> exchangeFirebaseToken({
    required String firebaseToken,
    String? firstName,
    String? lastName,
  }) async {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    try {
      final response = await _dio.post<dynamic>(
        exchangePath,
        data: {
          'firebase_token': firebaseToken,
          if (first.isNotEmpty) 'first_name': first,
          if (last.isNotEmpty) 'last_name': last,
        },
      );
      final data = response.data;
      final auth = data is Map ? data['auth'] : null;
      final accessToken = auth is Map ? auth['access_token'] : null;
      final refreshToken = auth is Map ? auth['refresh_token'] : null;
      if (accessToken is! String ||
          accessToken.isEmpty ||
          refreshToken is! String ||
          refreshToken.isEmpty) {
        throw const AuthApiException(200, 'Token response malformed');
      }
      return SessionTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (e) {
      final failure = _apiFailure(e);
      if (failure == null) rethrow;
      if (failure.statusCode == 422 &&
          _namesRequiredDetails.contains(failure.detail?.trim().toLowerCase())) {
        throw const ProfileNamesRequiredException();
      }
      throw failure;
    }
  }

  /// A new access token for [refreshToken]. The refresh token itself is not
  /// renewed by the backend.
  Future<String> refreshAccessToken(String refreshToken) async {
    try {
      final response = await _dio.post<dynamic>(
        refreshPath,
        data: {'token': refreshToken},
      );
      final data = response.data;
      final accessToken = data is Map ? data['access_token'] : null;
      if (accessToken is! String || accessToken.isEmpty) {
        throw const AuthApiException(200, 'Token response malformed');
      }
      return accessToken;
    } on DioException catch (e) {
      final failure = _apiFailure(e);
      if (failure == null) rethrow;
      throw failure;
    }
  }

  /// null when the server never answered (offline, timeout): not a verdict.
  AuthApiException? _apiFailure(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == null) return null;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] : null;
    return AuthApiException(statusCode, detail is String ? detail : null);
  }
}

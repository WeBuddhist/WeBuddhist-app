import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/auth/data/session/auth_token_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [status] and [body], or throws [error].
class _Adapter implements HttpClientAdapter {
  int status = 200;
  Object? body;
  DioException? error;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error != null) throw error!;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late AuthTokenApi api;

  setUp(() {
    adapter = _Adapter();
    api = AuthTokenApi(
      Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
        ..httpClientAdapter = adapter,
    );
  });

  TypeMatcher<AuthApiException> apiException(int status) =>
      isA<AuthApiException>().having((e) => e.statusCode, 'status', status);

  group('exchangeFirebaseToken', () {
    test('posts the token and reads the session from `auth`', () async {
      adapter.body = {
        'user_id': 'u-1',
        'email': 'tenzin@example.com',
        'message': 'Authentication successful',
        'user': {'name': 'Tenzin Dolma'},
        'auth': {
          'access_token': 'access',
          'refresh_token': 'refresh',
          'token_type': 'Bearer',
        },
      };

      final tokens = await api.exchangeFirebaseToken(
        firebaseToken: 'firebase',
        firstName: ' Tenzin ',
        lastName: 'Dolma',
      );

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'refresh');
      final request = adapter.requests.single;
      expect(request.path, '/auth/firebase/exchange');
      expect(request.data, {
        'firebase_token': 'firebase',
        'first_name': 'Tenzin',
        'last_name': 'Dolma',
      });
    });

    test('leaves out names it does not have', () async {
      adapter.body = {
        'auth': {'access_token': 'a', 'refresh_token': 'r'},
      };

      await api.exchangeFirebaseToken(firebaseToken: 'firebase', lastName: ' ');

      expect(adapter.requests.single.data, {'firebase_token': 'firebase'});
    });

    for (final detail in [
      'First name and last name are required for a new profile',
      'First name and last name are required for a new phone profile',
    ]) {
      test('422 "$detail" asks for names', () async {
        adapter
          ..status = 422
          ..body = {'detail': detail};

        await expectLater(
          api.exchangeFirebaseToken(firebaseToken: 'firebase'),
          throwsA(isA<ProfileNamesRequiredException>()),
        );
      });
    }

    test('a validation 422 is an ordinary refusal', () async {
      adapter
        ..status = 422
        ..body = {
          'detail': [
            {'loc': ['body', 'firebase_token'], 'msg': 'Field required'},
          ],
        };

      await expectLater(
        api.exchangeFirebaseToken(firebaseToken: 'firebase'),
        throwsA(apiException(422)),
      );
    });

    test('401 and 403 carry their status and detail', () async {
      adapter
        ..status = 401
        ..body = {'detail': 'Invalid Firebase token'};
      await expectLater(
        api.exchangeFirebaseToken(firebaseToken: 'firebase'),
        throwsA(
          apiException(
            401,
          ).having((e) => e.detail, 'detail', 'Invalid Firebase token'),
        ),
      );

      adapter.status = 403;
      await expectLater(
        api.exchangeFirebaseToken(firebaseToken: 'firebase'),
        throwsA(apiException(403)),
      );
    });

    test('a 200 without tokens is refused, not stored', () async {
      adapter.body = {
        'auth': {'access_token': 'a'},
      };

      await expectLater(
        api.exchangeFirebaseToken(firebaseToken: 'firebase'),
        throwsA(isA<AuthApiException>()),
      );
    });

    test('no answer from the server stays a DioException', () async {
      adapter.error = DioException(
        requestOptions: RequestOptions(path: '/auth/firebase/exchange'),
        type: DioExceptionType.connectionError,
      );

      await expectLater(
        api.exchangeFirebaseToken(firebaseToken: 'firebase'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('refreshAccessToken', () {
    test('posts the refresh token as `token`', () async {
      adapter.body = {'access_token': 'new-access', 'token_type': 'Bearer'};

      expect(await api.refreshAccessToken('refresh'), 'new-access');
      final request = adapter.requests.single;
      expect(request.path, '/auth/refresh-token');
      expect(request.data, {'token': 'refresh'});
    });

    test('401 carries the backend detail', () async {
      adapter
        ..status = 401
        ..body = {'detail': 'Refresh token expired'};

      await expectLater(
        api.refreshAccessToken('refresh'),
        throwsA(
          apiException(
            401,
          ).having((e) => e.detail, 'detail', 'Refresh token expired'),
        ),
      );
    });

    test('a 200 without an access token is refused', () async {
      adapter.body = {'token_type': 'Bearer'};

      await expectLater(
        api.refreshAccessToken('refresh'),
        throwsA(isA<AuthApiException>()),
      );
    });

    test('no answer from the server stays a DioException', () async {
      adapter.error = DioException(
        requestOptions: RequestOptions(path: '/auth/refresh-token'),
        type: DioExceptionType.connectionTimeout,
      );

      await expectLater(
        api.refreshAccessToken('refresh'),
        throwsA(isA<DioException>()),
      );
    });
  });
}

import 'dart:convert';

import 'package:flutter_pecha/features/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal, unsigned JWT (`header.payload.signature`) whose payload
/// carries the given [exp] (seconds since epoch). Signature is irrelevant to
/// the client-side expiry helpers, which only decode the payload.
String _jwtWithExp(int? exp) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg({'alg': 'HS256', 'typ': 'JWT'});
  final payload = seg({if (exp != null) 'exp': exp, 'sub': 'user-123'});
  return '$header.$payload.signature';
}

int _nowSecs() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

void main() {
  final auth = AuthService.instance;

  group('isJwtExpired', () {
    test('returns false for a token well within its lifetime', () {
      final jwt = _jwtWithExp(_nowSecs() + 3600);
      expect(auth.isJwtExpired(jwt), isFalse);
    });

    test('returns true for an already-expired token', () {
      final jwt = _jwtWithExp(_nowSecs() - 10);
      expect(auth.isJwtExpired(jwt), isTrue);
    });

    test('treats a token inside the buffer window as expired', () {
      // 60s left, default buffer is 120s ⇒ considered expired.
      final jwt = _jwtWithExp(_nowSecs() + 60);
      expect(auth.isJwtExpired(jwt), isTrue);
    });

    test('respects a custom buffer', () {
      final jwt = _jwtWithExp(_nowSecs() + 60);
      expect(auth.isJwtExpired(jwt, bufferSeconds: 30), isFalse);
    });

    test('treats malformed tokens as expired', () {
      expect(auth.isJwtExpired('not-a-jwt'), isTrue);
      expect(auth.isJwtExpired(_jwtWithExp(null)), isTrue);
    });
  });

  group('jwtRemainingTtlSeconds', () {
    test('returns the remaining lifetime for a live token', () {
      final jwt = _jwtWithExp(_nowSecs() + 300);
      final ttl = auth.jwtRemainingTtlSeconds(jwt);
      expect(ttl, inInclusiveRange(295, 300));
    });

    test('returns 0 for an expired token', () {
      final jwt = _jwtWithExp(_nowSecs() - 10);
      expect(auth.jwtRemainingTtlSeconds(jwt), 0);
    });

    test('returns 0 for a malformed token', () {
      expect(auth.jwtRemainingTtlSeconds('garbage'), 0);
      expect(auth.jwtRemainingTtlSeconds(_jwtWithExp(null)), 0);
    });
  });

  group('isSessionPermanentlyLost', () {
    test('no stored session is permanent', () {
      expect(
        AuthService.isSessionPermanentlyLost(
          AuthException('No session', code: AuthService.noSessionCode),
        ),
        isTrue,
      );
    });

    test('a refresh token the backend rejected (401) is permanent', () {
      expect(
        AuthService.isSessionPermanentlyLost(
          AuthException('rejected', code: AuthService.refreshRejectedCode),
        ),
        isTrue,
      );
    });

    test('a refresh refused with another 4xx is NOT permanent at launch', () {
      // Could be a wrong base URL or a backend fault: not grounds to wipe a
      // session unless a request just proved we are online (see below).
      expect(
        AuthService.isSessionPermanentlyLost(
          AuthException('refused', code: AuthService.refreshRefusedCode),
        ),
        isFalse,
      );
    });

    test('unrelated and untyped errors are transient', () {
      expect(
        AuthService.isSessionPermanentlyLost(AuthException('network blip')),
        isFalse,
      );
      expect(
        AuthService.isSessionPermanentlyLost(Exception('keystore')),
        isFalse,
      );
    });
  });

  group('isTokenRenewalFailed', () {
    test('true for a rejected and for a refused refresh', () {
      expect(
        AuthService.isTokenRenewalFailed(
          AuthException('rejected', code: AuthService.refreshRejectedCode),
        ),
        isTrue,
      );
      expect(
        AuthService.isTokenRenewalFailed(
          AuthException('refused', code: AuthService.refreshRefusedCode),
        ),
        isTrue,
      );
    });

    test('false for unrelated errors', () {
      expect(AuthService.isTokenRenewalFailed(AuthException('x')), isFalse);
      expect(
        AuthService.isTokenRenewalFailed(
          AuthException('No session', code: AuthService.noSessionCode),
        ),
        isFalse,
      );
      expect(AuthService.isTokenRenewalFailed(Exception('offline')), isFalse);
    });
  });
}

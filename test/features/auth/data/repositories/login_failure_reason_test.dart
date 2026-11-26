import 'package:flutter_pecha/features/auth/auth_service.dart';
import 'package:flutter_pecha/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_pecha/features/auth/domain/failures/login_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LoginFailureReason reasonFor(String? code) =>
      loginFailureReasonFor(AuthException('x', code: code));

  test('AuthService codes', () {
    expect(reasonFor(AuthService.cancelledCode), LoginFailureReason.cancelled);
    expect(reasonFor('network'), LoginFailureReason.network);
    expect(reasonFor('not-configured'), LoginFailureReason.notConfigured);
  });

  test('Firebase phone codes', () {
    expect(
      reasonFor('invalid-phone-number'),
      LoginFailureReason.invalidPhoneNumber,
    );
    expect(
      reasonFor('invalid-verification-code'),
      LoginFailureReason.invalidCode,
    );
    expect(reasonFor('session-expired'), LoginFailureReason.codeExpired);
    expect(reasonFor('too-many-requests'), LoginFailureReason.tooManyRequests);
    expect(reasonFor('quota-exceeded'), LoginFailureReason.tooManyRequests);
    expect(reasonFor('network-request-failed'), LoginFailureReason.network);
  });

  test('the exchange refusing an unverified email', () {
    expect(reasonFor('http_403'), LoginFailureReason.emailNotVerified);
  });

  test('anything else is unknown, including untyped errors', () {
    expect(reasonFor('http_500'), LoginFailureReason.unknown);
    expect(reasonFor('http_422'), LoginFailureReason.unknown);
    expect(reasonFor('app-not-authorized'), LoginFailureReason.unknown);
    expect(reasonFor(null), LoginFailureReason.unknown);
    expect(
      loginFailureReasonFor(StateError('boom')),
      LoginFailureReason.unknown,
    );
  });
}

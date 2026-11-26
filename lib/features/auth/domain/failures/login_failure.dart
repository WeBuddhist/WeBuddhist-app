import 'package:flutter_pecha/core/error/failures.dart';

/// Why a sign-in did not finish, for the screen to word.
enum LoginFailureReason {
  /// The person closed the sign-in sheet. Nothing to show.
  cancelled,

  invalidPhoneNumber,
  invalidCode,

  /// The SMS code is too old; a new one has to be sent.
  codeExpired,
  tooManyRequests,
  network,

  /// The provider has not verified this account's email address.
  emailNotVerified,

  /// Sign-in is not set up in this build.
  notConfigured,
  unknown,
}

/// A sign-in that did not finish. An [AuthenticationFailure], so code that
/// only tells login failures from others is unaffected.
class LoginFailure extends AuthenticationFailure {
  const LoginFailure(super.message, this.reason);

  final LoginFailureReason reason;

  @override
  List<Object> get props => [...super.props, reason];
}

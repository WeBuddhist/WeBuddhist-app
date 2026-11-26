import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/auth/domain/entities/auth_credentials.dart';

/// What happened after a phone number was submitted for sign-in.
class PhoneCodeStart extends Equatable {
  /// An SMS code went out; finish with it and [verificationId].
  const PhoneCodeStart.codeSent({
    required String this.verificationId,
    this.resendToken,
    this.autoSignIn,
  }) : credentials = null;

  /// The number was verified without a code (Android can do this), so the
  /// sign-in is already complete.
  const PhoneCodeStart.signedIn(AuthCredentials this.credentials)
    : verificationId = null,
      resendToken = null,
      autoSignIn = null;

  final String? verificationId;

  /// Pass back when asking for the code again.
  final int? resendToken;

  final AuthCredentials? credentials;

  /// After a code went out: completes with the credentials if Android reads
  /// the SMS and signs in by itself, so the code never has to be typed.
  /// Completes with null if it does not; never completes on iOS.
  final Future<AuthCredentials?>? autoSignIn;

  bool get isSignedIn => credentials != null;

  @override
  List<Object?> get props => [verificationId, resendToken, credentials];
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// What a Firebase sign-in proves to the backend: a fresh ID token, plus the
/// name the provider shared, used only when the account is new.
class FirebaseProof {
  const FirebaseProof({required this.idToken, this.firstName, this.lastName});

  final String idToken;
  final String? firstName;
  final String? lastName;
}

/// A Firebase sign-in that did not produce a proof.
class FirebaseSignInException implements Exception {
  const FirebaseSignInException(this.code, [this.message]);

  /// The person closed the sheet or the browser. Not an error to show.
  static const cancelled = 'cancelled';

  /// Firebase is not set up in this build.
  static const notConfigured = 'not-configured';

  /// One of the above, or the Firebase / Google error code as is, e.g.
  /// `invalid-phone-number`, `invalid-verification-code`, `session-expired`,
  /// `too-many-requests`, `network-request-failed`.
  final String code;
  final String? message;

  bool get isCancelled => code == cancelled;

  @override
  String toString() =>
      'FirebaseSignInException($code)${message == null ? '' : ': $message'}';
}

/// How a phone verification started.
sealed class PhoneVerificationStart {
  const PhoneVerificationStart();
}

/// An SMS went out; the person types the code in.
class PhoneVerificationCodeSent extends PhoneVerificationStart {
  const PhoneVerificationCodeSent({
    required this.verificationId,
    this.resendToken,
    this.autoVerified,
  });

  final String verificationId;

  /// Pass back to resend to the same number (Android only).
  final int? resendToken;

  /// Android can read the SMS itself. When it does, this completes with the
  /// proof and nobody has to type the code. Completes with null when the
  /// wait for the SMS ran out; never completes on iOS.
  final Future<FirebaseProof?>? autoVerified;
}

/// Android verified the number without a code.
class PhoneVerificationAutoVerified extends PhoneVerificationStart {
  const PhoneVerificationAutoVerified(this.proof);

  final FirebaseProof proof;
}

/// "Tenzin Dolma Lhamo" -> first "Tenzin", last "Dolma Lhamo".
({String? first, String? last}) splitDisplayName(String? displayName) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty) return (first: null, last: null);
  final space = name.indexOf(RegExp(r'\s'));
  if (space == -1) return (first: name, last: null);
  final last = name.substring(space + 1).trim();
  return (first: name.substring(0, space), last: last.isEmpty ? null : last);
}

/// Google, Apple and phone sign-in through Firebase Authentication.
///
/// Firebase only proves who the person is. Each method signs in, takes the ID
/// token and signs out again at once: the backend's tokens are the session,
/// and the app's Firebase user belongs to the live-updates sign-in
/// (`FirebaseSessionNotifier`), whose uid is the backend user id.
abstract class FirebaseSignIn {
  Future<FirebaseProof> signInWithGoogle();

  Future<FirebaseProof> signInWithApple();

  /// Sends an SMS code to [phoneNumber] (E.164).
  Future<PhoneVerificationStart> verifyPhoneNumber(
    String phoneNumber, {
    int? resendToken,
  });

  Future<FirebaseProof> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  });

  /// Forgets the Google account so the next sign-in asks which one to use.
  Future<void> signOutProviders();
}

class FirebaseSignInImpl implements FirebaseSignIn {
  FirebaseSignInImpl({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _authOverride = auth,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn _googleSignIn;

  Future<void>? _googleInitialized;

  FirebaseAuth get _auth {
    final override = _authOverride;
    if (override != null) return override;
    if (Firebase.apps.isEmpty) {
      throw const FirebaseSignInException(
        FirebaseSignInException.notConfigured,
        'Firebase is not initialised',
      );
    }
    return FirebaseAuth.instance;
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialized ??= _googleSignIn
        .initialize(
          // Android reads its ids from google-services.json. iOS takes the
          // client id from the bundled GoogleService-Info.plist, which
          // differs per flavor.
          clientId:
              defaultTargetPlatform == TargetPlatform.iOS
                  ? Firebase.app().options.iosClientId
                  : null,
        )
        .catchError((Object e) {
          _googleInitialized = null;
          throw e;
        });
  }

  @override
  Future<FirebaseProof> signInWithGoogle() async {
    final auth = _auth;
    try {
      await _ensureGoogleInitialized();
      final account = await _googleSignIn.authenticate();
      final googleIdToken = account.authentication.idToken;
      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw const FirebaseSignInException(
          'missing-google-id-token',
          'Google returned no ID token',
        );
      }
      return await _proofFor(
        auth,
        () => auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: googleIdToken),
        ),
        fallbackName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      throw FirebaseSignInException(
        e.code == GoogleSignInExceptionCode.canceled
            ? FirebaseSignInException.cancelled
            : 'google-${e.code.name}',
        e.description,
      );
    } finally {
      unawaited(signOutProviders());
    }
  }

  @override
  Future<FirebaseProof> signInWithApple() {
    final auth = _auth;
    final provider =
        AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
    return _proofFor(auth, () => auth.signInWithProvider(provider));
  }

  @override
  Future<PhoneVerificationStart> verifyPhoneNumber(
    String phoneNumber, {
    int? resendToken,
  }) async {
    final auth = _auth;
    final started = Completer<PhoneVerificationStart>();
    final autoVerified = Completer<FirebaseProof?>();
    void fail(Object error) {
      if (!started.isCompleted) started.completeError(error);
    }

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        verificationCompleted: (credential) async {
          // Android only. Before the code screen is up: the number was
          // verified without an SMS. After: Android read the SMS itself.
          final instant = !started.isCompleted;
          if (!instant && autoVerified.isCompleted) return;
          try {
            final proof = await _proofFor(
              auth,
              () => auth.signInWithCredential(credential),
            );
            if (instant && !started.isCompleted) {
              started.complete(PhoneVerificationAutoVerified(proof));
            } else if (!autoVerified.isCompleted) {
              autoVerified.complete(proof);
            }
          } catch (e) {
            if (instant) {
              fail(e);
            } else if (!autoVerified.isCompleted) {
              // The person can still type the code.
              autoVerified.complete(null);
            }
          }
        },
        verificationFailed: (e) => fail(_fromFirebase(e)),
        codeSent: (verificationId, resendToken) {
          if (started.isCompleted) return;
          started.complete(
            PhoneVerificationCodeSent(
              verificationId: verificationId,
              resendToken: resendToken,
              autoVerified: autoVerified.future,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {
          if (!autoVerified.isCompleted) autoVerified.complete(null);
        },
      );
    } on FirebaseAuthException catch (e) {
      fail(_fromFirebase(e));
    }
    return started.future;
  }

  @override
  Future<FirebaseProof> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final auth = _auth;
    return _proofFor(
      auth,
      () => auth.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        ),
      ),
    );
  }

  @override
  Future<void> signOutProviders() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Nothing to forget, or Google sign-in is not set up in this build.
    }
  }

  /// Signs in, reads the ID token and signs out again before returning, so a
  /// Firebase user from sign-in never outlives it: one left signed in would
  /// be mistaken for the live-updates user on the next launch. The token stays
  /// valid for the exchange; a client sign-out does not revoke it.
  Future<FirebaseProof> _proofFor(
    FirebaseAuth auth,
    Future<UserCredential> Function() signIn, {
    String? fallbackName,
  }) async {
    try {
      final credential = await signIn();
      final user = credential.user;
      final idToken = await user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const FirebaseSignInException(
          'missing-id-token',
          'Firebase returned no ID token',
        );
      }
      final userName = user?.displayName?.trim() ?? '';
      final name = splitDisplayName(
        userName.isNotEmpty ? userName : fallbackName,
      );
      return FirebaseProof(
        idToken: idToken,
        firstName: name.first,
        lastName: name.last,
      );
    } on FirebaseAuthException catch (e) {
      throw _fromFirebase(e);
    } finally {
      try {
        await auth.signOut();
      } catch (_) {
        // The live-updates sign-in replaces any user left behind.
      }
    }
  }

  FirebaseSignInException _fromFirebase(FirebaseAuthException e) {
    const cancelCodes = {
      'canceled',
      'cancelled',
      'web-context-canceled',
      'web-context-cancelled',
      'user-cancelled',
      'popup-closed-by-user',
    };
    return FirebaseSignInException(
      cancelCodes.contains(e.code) ? FirebaseSignInException.cancelled : e.code,
      e.message,
    );
  }
}

// Authentication state
//
// Handles ONLY authentication concerns:
// - Login/logout status
// - Guest mode
// - Auth loading states
// - Auth errors
// - Onboarding completion (fetched once at login, owned here to avoid
//   per-navigation network calls in the route guard)
//
// User profile data is now managed by UserNotifier (userProvider)

import 'package:flutter_pecha/features/auth/domain/failures/login_failure.dart';

// Sentinel used by copyWith so callers can explicitly pass null for
// hasCompletedOnboarding without it being treated as "keep current value".
const _kSentinel = Object();

class AuthState {
  final bool isLoggedIn;

  /// The launch restore is still deciding who is signed in. The route guard
  /// shows the splash for as long as this is true.
  final bool isLoading;

  /// A Google or Apple sign-in is running. Unlike [isLoading] it does not
  /// move the app to the splash: the person stays where they tapped the
  /// button, which shows a spinner, so a guest who signs in from a prompt
  /// carries on where they were, and one who cancels or fails sees why.
  final bool isSigningIn;
  final bool isGuest;
  final String? errorMessage;

  /// null  = not yet known (offline, fetch failed, or retry pending).
  /// true  = onboarding completed.
  /// false = onboarding not completed.
  ///
  /// The route guard reads this synchronously. Unknown status fail-opens to
  /// home; [AuthNotifier] retries the fetch in the background.
  final bool? hasCompletedOnboarding;

  /// Why the last Google or Apple sign-in failed, for the login page and
  /// drawer to show under their buttons. Like [errorMessage], cleared by the
  /// next state change. Phone sign-in shows its failures on its own screen.
  final LoginFailureReason? loginError;

  const AuthState({
    required this.isLoggedIn,
    this.isGuest = false,
    this.isLoading = false,
    this.isSigningIn = false,
    this.errorMessage,
    this.hasCompletedOnboarding,
    this.loginError,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    bool? isSigningIn,
    bool? isGuest,
    String? errorMessage,
    LoginFailureReason? loginError,
    // Use _kSentinel as default so passing null explicitly resets the field to
    // null rather than being treated as "no change".
    Object? hasCompletedOnboarding = _kSentinel,
  }) => AuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    isLoading: isLoading ?? this.isLoading,
    isSigningIn: isSigningIn ?? this.isSigningIn,
    isGuest: isGuest ?? this.isGuest,
    errorMessage: errorMessage,
    loginError: loginError,
    hasCompletedOnboarding: identical(hasCompletedOnboarding, _kSentinel)
        ? this.hasCompletedOnboarding
        : hasCompletedOnboarding as bool?,
  );

  AuthState clearError() => copyWith(errorMessage: '');
}

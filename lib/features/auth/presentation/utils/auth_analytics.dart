import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which screen started a login or guest session, carried as `source`.
enum AuthSource {
  loginPage,
  loginDrawer,
  onboarding,
  meScreen;

  String get key => switch (this) {
    AuthSource.loginPage => 'login_page',
    AuthSource.loginDrawer => 'login_drawer',
    AuthSource.onboarding => 'onboarding',
    AuthSource.meScreen => 'me_screen',
  };
}

/// The wrappers the repository and `AuthService` put around every message;
/// `method` already says which provider it was.
final _loginMessagePrefix = RegExp(
  r'^(?:\w+ login failed: |AuthException: |Login failed: )+',
);

/// The readable part of an iOS error dump, without its `UserInfo`.
final _nsErrorDescription = RegExp(r'Error Domain=\S+ Code=-?\d+ "([^"]*)"');

/// URLs, the Auth0 domain, email addresses and phone-like numbers.
final _sensitiveLoginText = RegExp(
  r'https?://\S+|[\w.-]+\.auth0\.com|[\w.+-]+@[\w.-]+|\+?\d[\d\s-]{6,}\d',
);

const _loginDetailMaxLength = 200;

/// Readable login failure text for `reason_detail`, which keeps the detail
/// `reason_code` groups away: wrappers and sensitive text removed, length capped.
String cleanLoginFailureMessage(String message) {
  var text = message.trim().replaceFirst(_loginMessagePrefix, '');
  text = _nsErrorDescription.firstMatch(text)?.group(1) ?? text;
  text = text.replaceAll(_sensitiveLoginText, '<redacted>');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= _loginDetailMaxLength
      ? text
      : text.substring(0, _loginDetailMaxLength);
}

/// Why a login failed, carried as `reason_code` for charts. The raw error text
/// is long, varies per device and can contain the Auth0 domain, so it is never
/// sent; see [cleanLoginFailureMessage] for what is.
enum LoginFailureCode {
  userCancelled,
  noBrowser,
  network,
  config,
  unexpected;

  String get key => switch (this) {
    LoginFailureCode.userCancelled => 'user_cancelled',
    LoginFailureCode.noBrowser => 'no_browser',
    LoginFailureCode.network => 'network',
    LoginFailureCode.config => 'config',
    LoginFailureCode.unexpected => 'unexpected',
  };

  /// Reads the text [AuthService] produces (and, before the move to
  /// Firebase, the Auth0 SDKs). Analytics is given only that text, not the
  /// exception or its code.
  factory LoginFailureCode.fromMessage(String message) {
    final text = message.toLowerCase();
    if (text.contains('user closed the browser') ||
        text.contains('user cancelled') ||
        text.contains('cancelled by user') ||
        text.contains('did not authorize')) {
      return LoginFailureCode.userCancelled;
    }
    if (text.contains('no compatible browser')) {
      return LoginFailureCode.noBrowser;
    }
    if (text.contains('not configured') ||
        text.contains('associated domains')) {
      return LoginFailureCode.config;
    }
    if (text.contains('network') || text.contains('nsurlerror')) {
      return LoginFailureCode.network;
    }
    return LoginFailureCode.unexpected;
  }
}

/// Product analytics for auth: one method per tracked action, so the event
/// names and their property keys live in one place. Every call fires and
/// forgets; callers fire after the action happened, never optimistically.
class AuthAnalytics {
  const AuthAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// The user tapped a provider button; [method] is `google`, `apple` or
  /// `sms` (the Auth0 connection names, kept so charts stay continuous).
  void loginStarted({required String method, required AuthSource source}) {
    _analytics.trackInBackground(AnalyticsEvents.authLoginStarted, {
      AnalyticsProperties.method: method,
      AnalyticsProperties.source: source.key,
    });
  }

  /// [source] is null when login started somewhere other than the login page
  /// or drawer. [isNewUser] is true when the account has not finished
  /// onboarding, null when that could not be checked.
  ///
  /// A new account also records its sign-up method on the person, once.
  void loginSucceeded({String? method, AuthSource? source, bool? isNewUser}) {
    final resolvedMethod = method ?? 'default';
    _analytics.trackInBackground(AnalyticsEvents.authLoginSucceeded, {
      AnalyticsProperties.method: resolvedMethod,
      AnalyticsProperties.source: source?.key,
      if (isNewUser != null) AnalyticsProperties.isNewUser: isNewUser,
      if (isNewUser == true)
        AnalyticsProperties.personSetOnce: {
          AnalyticsProperties.signupMethod: resolvedMethod,
        },
    });
  }

  /// The user logged out from the Me page. Sent before the identity reset.
  void loggedOut() {
    _analytics.trackInBackground(AnalyticsEvents.authLogout, const {});
  }

  /// The server deleted the account. Sent before the identity reset.
  void accountDeleted() {
    _analytics.trackInBackground(AnalyticsEvents.accountDeleted, const {});
  }

  /// [failureMessage] is mapped to a code and cleaned; it is never sent as is.
  void loginFailed({
    String? method,
    AuthSource? source,
    required String failureMessage,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.authLoginFailed, {
      AnalyticsProperties.method: method ?? 'default',
      AnalyticsProperties.source: source?.key,
      AnalyticsProperties.reasonCode:
          LoginFailureCode.fromMessage(failureMessage).key,
      AnalyticsProperties.reasonDetail: cleanLoginFailureMessage(
        failureMessage,
      ),
    });
  }

  /// Guest mode was persisted.
  void guestStarted({required AuthSource source}) {
    _analytics.trackInBackground(AnalyticsEvents.authGuestStarted, {
      AnalyticsProperties.source: source.key,
    });
  }

  /// The login drawer opened; [feature] is what asked for login.
  void loginPromptShown({required String feature}) {
    _analytics.trackInBackground(AnalyticsEvents.loginPromptShown, {
      AnalyticsProperties.feature: feature,
    });
  }

  /// The login drawer closed before a login finished in it. [loginAttempted]
  /// is true when a login was started from the drawer: the splash screen
  /// shown while it runs closes the drawer.
  void loginPromptDismissed({
    required String feature,
    required bool loginAttempted,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.loginPromptDismissed, {
      AnalyticsProperties.feature: feature,
      AnalyticsProperties.loginAttempted: loginAttempted,
    });
  }
}

final authAnalyticsProvider = Provider<AuthAnalytics>((ref) {
  return AuthAnalytics(ref.watch(analyticsServiceProvider));
});

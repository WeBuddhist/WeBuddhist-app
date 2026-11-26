import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/start_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

/// Stands in for the auth notifier: records the logins it is asked for.
class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState(isLoggedIn: true, isGuest: true));

  final List<({String? connection, AuthSource? source})> logins = [];

  @override
  Future<void> login({String? connection, AuthSource? source}) async {
    logins.add((connection: connection, source: source));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Auth auth;
  late RecordingAnalyticsService analytics;

  /// A screen with one "Continue with …" button for [connection], as the
  /// login page, the login drawer and the guest Me tab each have.
  Future<void> tapButton(
    WidgetTester tester, {
    required String connection,
    required AuthSource source,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder:
                (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => startSignIn(
                          context,
                          ref,
                          connection: connection,
                          source: source,
                        ),
                    child: const Text('continue'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('continue'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    auth = _Auth();
    analytics = RecordingAnalyticsService();
  });

  testWidgets('phone opens the phone screen instead of asking for a login', (
    tester,
  ) async {
    // The guest Me tab used to hand "sms" to AuthNotifier.login, which has
    // no phone sign-in to run, so its button did nothing.
    await tapButton(
      tester,
      connection: AuthNotifier.phoneConnection,
      source: AuthSource.meScreen,
    );

    expect(find.byType(PhoneLoginScreen), findsOneWidget);
    expect(auth.logins, isEmpty);
  });

  testWidgets('Google and Apple sign in where they are', (tester) async {
    await tapButton(
      tester,
      connection: 'google',
      source: AuthSource.loginDrawer,
    );

    expect(auth.logins.single, (
      connection: 'google',
      source: AuthSource.loginDrawer,
    ));
    expect(find.byType(PhoneLoginScreen), findsNothing);
  });

  testWidgets('every start is reported with its method and source', (
    tester,
  ) async {
    await tapButton(
      tester,
      connection: AuthNotifier.phoneConnection,
      source: AuthSource.meScreen,
    );

    final started = analytics.events.singleWhere(
      (e) => e.name == AnalyticsEvents.authLoginStarted,
    );
    expect(started.properties, {
      AnalyticsProperties.method: 'sms',
      AnalyticsProperties.source: 'me_screen',
    });
  });
}

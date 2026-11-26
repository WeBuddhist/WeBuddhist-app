import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

/// A guest whose login can start without reaching Auth0.
class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState(isLoggedIn: false, isGuest: true));

  /// What `login()` does first; the route guard then shows the splash screen.
  void startLogin() => state = state.copyWith(isLoading: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late RecordingAnalyticsService service;
  late _Auth auth;

  setUp(() {
    service = RecordingAnalyticsService();
    auth = _Auth();
  });

  Future<void> openPrompt(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          authAnalyticsProvider.overrideWithValue(AuthAnalytics(service)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder:
                (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => LoginDrawer.show(context, ref, feature: 'mala'),
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// Closes the prompt the way a drag, the barrier or the splash redirect do.
  Future<void> closePrompt(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(LoginDrawer))).pop();
    await tester.pumpAndSettle();
  }

  Map<String, Object?> dismissal() =>
      service.events
          .singleWhere((e) => e.name == AnalyticsEvents.loginPromptDismissed)
          .properties;

  testWidgets('closing the prompt without logging in is a plain dismissal', (
    tester,
  ) async {
    await openPrompt(tester);
    await closePrompt(tester);

    expect(dismissal(), {'feature': 'mala', 'login_attempted': false});
  });

  testWidgets('a login started from the prompt marks its dismissal', (
    tester,
  ) async {
    await openPrompt(tester);
    auth.startLogin();
    await closePrompt(tester);

    expect(dismissal(), {'feature': 'mala', 'login_attempted': true});
  });
}

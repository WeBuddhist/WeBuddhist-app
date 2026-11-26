import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/last_sign_in_method_provider.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_form_widgets.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/social_login_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState(isLoggedIn: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('isLastUsedConnection', () {
    test('matches the button for the stored method', () {
      expect(isLastUsedConnection('google', 'google'), isTrue);
      expect(isLastUsedConnection('apple', 'apple'), isTrue);
      // The phone button is the "sms" connection; it is stored as "phone".
      expect(isLastUsedConnection('phone', AuthNotifier.phoneConnection), isTrue);
    });

    test('no other button, and none when nothing is stored', () {
      expect(isLastUsedConnection('google', 'apple'), isFalse);
      expect(isLastUsedConnection('phone', 'google'), isFalse);
      expect(isLastUsedConnection(null, 'google'), isFalse);
    });
  });

  /// The three sign-in buttons, with [lastUsed] as the method remembered on
  /// this phone.
  Future<AppLocalizations> pumpButtons(
    WidgetTester tester, {
    required String? lastUsed,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _Auth()),
          analyticsServiceProvider.overrideWithValue(
            RecordingAnalyticsService(),
          ),
          lastSignInMethodProvider.overrideWithValue(lastUsed),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  for (final connection in ['apple', 'google', 'sms']) ...[
                    SocialLoginButton(
                      key: ValueKey(connection),
                      connection: connection,
                      icon: Icons.login,
                      iconColor: Colors.black,
                      label: 'Continue with $connection',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      iconWidget: const Icon(Icons.login),
                      source: AuthSource.loginPage,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return AppLocalizations.of(
      tester.element(find.byKey(const ValueKey('google'))),
    )!;
  }

  testWidgets('only the button last used on this phone is tagged', (
    tester,
  ) async {
    final l10n = await pumpButtons(tester, lastUsed: 'google');

    expect(find.text(l10n.login_last_used), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('google')),
        matching: find.text(l10n.login_last_used),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a phone last used tags the phone button', (tester) async {
    final l10n = await pumpButtons(tester, lastUsed: 'phone');

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sms')),
        matching: find.text(l10n.login_last_used),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a phone that has never signed in tags nothing', (tester) async {
    final l10n = await pumpButtons(tester, lastUsed: null);

    expect(find.text(l10n.login_last_used), findsNothing);
    expect(find.byType(LastUsedTag), findsNWidgets(3));
  });
}

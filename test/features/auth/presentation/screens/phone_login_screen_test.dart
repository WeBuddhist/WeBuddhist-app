import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/auth/domain/entities/phone_code_start.dart';
import 'package:flutter_pecha/features/auth/domain/failures/login_failure.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Stands in for the auth notifier: records what the screen asks for and
/// answers with what the test set.
class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState(isLoggedIn: false));

  Either<LoginFailure, PhoneCodeStart> codeResult = const Right(
    PhoneCodeStart.codeSent(verificationId: 'v-1', resendToken: 9),
  );
  LoginFailure? verifyResult;

  final List<({String number, int? resendToken})> codeRequests = [];
  final List<({String verificationId, String code})> verifications = [];

  @override
  Future<Either<LoginFailure, PhoneCodeStart>> requestPhoneCode(
    String phoneNumber, {
    int? resendToken,
    AuthSource? source,
  }) async {
    codeRequests.add((number: phoneNumber, resendToken: resendToken));
    return codeResult;
  }

  @override
  Future<LoginFailure?> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
    AuthSource? source,
  }) async {
    verifications.add((verificationId: verificationId, code: smsCode));
    if (verifyResult == null) signIn();
    return verifyResult;
  }

  /// How often the screen dropped a pending automatic sign-in.
  int phoneSignInCancels = 0;

  @override
  void cancelPhoneSignIn() => phoneSignInCancels++;

  void signIn() => state = state.copyWith(isLoggedIn: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('composeE164', () {
    test('joins the country code and the national number', () {
      expect(composeE164('91', '98765 43210'), '+919876543210');
      expect(composeE164('1', '(415) 555-0100'), '+14155550100');
    });

    test('drops a leading trunk zero', () {
      expect(composeE164('44', '07700 900123'), '+447700900123');
    });

    test('takes a number typed with its own + as complete', () {
      expect(composeE164('91', '+1 415 555 0100'), '+14155550100');
    });

    test('refuses what cannot be a phone number', () {
      expect(composeE164('91', ''), isNull);
      expect(composeE164('91', '000'), isNull);
      expect(composeE164('91', '12'), isNull);
      expect(composeE164('91', '1234567890123456'), isNull);
      expect(composeE164('91', '+0123456789'), isNull);
    });
  });

  group('PhoneLoginScreen', () {
    late _Auth auth;

    /// Opens the screen from a button, the way the login page does, so the
    /// screen has a route of its own to close.
    Future<AppLocalizations> open(WidgetTester tester) async {
      // The country starts from the phone's region, not the app language.
      tester.platformDispatcher.localeTestValue = const Locale('en', 'IN');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith((ref) => auth)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => PhoneLoginScreen.open(
                            context,
                            source: AuthSource.loginPage,
                          ),
                      child: const Text('open'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return AppLocalizations.of(tester.element(find.byType(PhoneLoginScreen)))!;
    }

    Future<void> sendCode(WidgetTester tester, AppLocalizations l10n) async {
      await tester.enterText(find.byType(TextField), '98765 43210');
      await tester.tap(find.text(l10n.phone_login_send_code));
      await tester.pumpAndSettle();
    }

    setUp(() => auth = _Auth());

    testWidgets('sends the number in E.164 and asks for the code', (
      tester,
    ) async {
      final l10n = await open(tester);
      expect(find.text(l10n.phone_login_title), findsOneWidget);

      await sendCode(tester, l10n);

      expect(auth.codeRequests.single, (
        number: '+919876543210',
        resendToken: null,
      ));
      expect(find.text(l10n.phone_login_code_title), findsOneWidget);
      expect(
        find.text(l10n.phone_login_code_subtitle('+919876543210')),
        findsOneWidget,
      );
    });

    testWidgets('a number that cannot be one is caught before any SMS', (
      tester,
    ) async {
      final l10n = await open(tester);

      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text(l10n.phone_login_send_code));
      await tester.pumpAndSettle();

      expect(auth.codeRequests, isEmpty);
      expect(find.text(l10n.login_error_invalid_phone), findsOneWidget);
    });

    testWidgets('shows why Firebase refused the number', (tester) async {
      auth.codeResult = const Left(
        LoginFailure('x', LoginFailureReason.tooManyRequests),
      );
      final l10n = await open(tester);

      await sendCode(tester, l10n);

      expect(find.text(l10n.login_error_too_many_requests), findsOneWidget);
      expect(find.text(l10n.phone_login_title), findsOneWidget);
    });

    testWidgets('the sixth digit verifies, and signing in closes the screen', (
      tester,
    ) async {
      final l10n = await open(tester);
      await sendCode(tester, l10n);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      expect(auth.verifications.single, (verificationId: 'v-1', code: '123456'));
      expect(find.byType(PhoneLoginScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a wrong code shows an error and stays on the code step', (
      tester,
    ) async {
      auth.verifyResult = const LoginFailure(
        'x',
        LoginFailureReason.invalidCode,
      );
      final l10n = await open(tester);
      await sendCode(tester, l10n);

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();

      expect(find.text(l10n.login_error_invalid_code), findsOneWidget);
      expect(find.text(l10n.phone_login_code_title), findsOneWidget);
    });

    testWidgets('resend waits, then reuses the number and the resend token', (
      tester,
    ) async {
      final l10n = await open(tester);
      await sendCode(tester, l10n);

      // Counting down: the button names the wait and does nothing.
      expect(find.text(l10n.phone_login_resend), findsNothing);
      await tester.tap(find.text(l10n.phone_login_resend_in(30)));
      await tester.pump();
      expect(auth.codeRequests, hasLength(1));

      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.text(l10n.phone_login_resend));
      await tester.pumpAndSettle();

      expect(auth.codeRequests.last, (
        number: '+919876543210',
        resendToken: 9,
      ));
      // Dispose the screen so its countdown timer is not left running.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"Change number" goes back to the number step', (tester) async {
      final l10n = await open(tester);
      await sendCode(tester, l10n);

      await tester.tap(find.text(l10n.phone_login_change_number));
      await tester.pumpAndSettle();

      expect(find.text(l10n.phone_login_title), findsOneWidget);
      // Android must not still sign in with the code for the old number.
      expect(auth.phoneSignInCancels, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('leaving while asked for the code drops its sign-in', (
      tester,
    ) async {
      final l10n = await open(tester);
      await sendCode(tester, l10n);

      await tester.pumpWidget(const SizedBox());

      expect(auth.phoneSignInCancels, 1);
    });

    testWidgets('leaving before a code is sent has nothing to drop', (
      tester,
    ) async {
      await open(tester);

      await tester.pumpWidget(const SizedBox());

      expect(auth.phoneSignInCancels, 0);
    });
  });
}

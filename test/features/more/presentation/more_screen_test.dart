import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/auth/domain/entities/user.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/user_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/auth/presentation/state/user_state.dart';
import 'package:flutter_pecha/features/more/presentation/more_screen.dart';
import 'package:flutter_pecha/features/more/presentation/providers/sign_in_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User extends StateNotifier<UserState> implements UserNotifier {
  _User(User? user) : super(UserState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _signedIn = AuthState(isLoggedIn: true);

const _tenzin = User(
  id: 'me',
  displayName: 'Tenzin Dolma',
  username: 'tenzin',
  email: 'tenzin@example.com',
);

Future<void> _pumpSettings(
  WidgetTester tester, {
  required AuthState auth,
  User? user,
  SignInAccount? account,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MoreScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _Auth(auth)),
        userProvider.overrideWith((ref) => _User(user)),
        signInAccountProvider.overrideWith((ref) async => account),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _scrollToLogout(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Log out'), 200);
}

void main() {
  testWidgets('shows no profile card or Edit profile row', (tester) async {
    await _pumpSettings(tester, auth: _signedIn, user: _tenzin);

    expect(find.text('tenzin'), findsNothing);
    expect(find.text('Tenzin Dolma'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
  });

  testWidgets('shows the Google email above Log out', (tester) async {
    await _pumpSettings(
      tester,
      auth: _signedIn,
      user: _tenzin,
      account: const SignInAccount(
        method: SignInMethod.google,
        identifier: 'tenzin@example.com',
      ),
    );
    await _scrollToLogout(tester);

    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('tenzin@example.com'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('tenzin@example.com')).dy,
      lessThan(tester.getTopLeft(find.text('Log out')).dy),
    );
  });

  testWidgets('shows the phone number for phone sign-in', (tester) async {
    await _pumpSettings(
      tester,
      auth: _signedIn,
      user: const User(id: 'me', username: 'tenzin'),
      account: const SignInAccount(
        method: SignInMethod.phone,
        identifier: '+66 81 234 5678',
      ),
    );
    await _scrollToLogout(tester);

    expect(find.text('Signed in with phone number'), findsOneWidget);
    expect(find.text('+66 81 234 5678'), findsOneWidget);
  });

  testWidgets('guests see Sign in and no account row', (tester) async {
    await _pumpSettings(
      tester,
      auth: const AuthState(isLoggedIn: true, isGuest: true),
      user: _tenzin,
      account: const SignInAccount(
        method: SignInMethod.google,
        identifier: 'tenzin@example.com',
      ),
    );
    await tester.scrollUntilVisible(find.text('Sign in'), 200);

    expect(find.text('tenzin@example.com'), findsNothing);
    expect(find.text('Log out'), findsNothing);
  });
}

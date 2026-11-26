import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts a sign-in from a "Continue with …" button. Every such button goes
/// through here, wherever it is (login page, login drawer, the Me tab), so
/// they cannot drift apart: [connection] is `google`, `apple`, or
/// [AuthNotifier.phoneConnection].
///
/// Google and Apple run in place. Phone sign-in takes a number and a code,
/// so it opens its own screen instead; asking [AuthNotifier.login] for it
/// would fail.
Future<void> startSignIn(
  BuildContext context,
  WidgetRef ref, {
  required String connection,
  required AuthSource source,
}) async {
  ref
      .read(authAnalyticsProvider)
      .loginStarted(method: connection, source: source);
  if (connection == AuthNotifier.phoneConnection) {
    await PhoneLoginScreen.open(context, source: source);
    return;
  }
  await ref
      .read(authProvider.notifier)
      .login(connection: connection, source: source);
}

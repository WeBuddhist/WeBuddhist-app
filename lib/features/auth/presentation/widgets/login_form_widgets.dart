import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/auth/domain/failures/login_failure.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/login_failure_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Field styling for the phone sign-in screen: the outlined, 12-radius field
/// the onboarding profile step uses.
InputDecoration loginFieldDecoration(
  BuildContext context, {
  String? hintText,
  String? errorText,
  Widget? prefixIcon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final idle = isDark ? AppColors.grey800 : AppColors.grey300;
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hintText,
    errorText: errorText,
    errorMaxLines: 3,
    prefixIcon: prefixIcon,
    counterText: '',
    filled: true,
    fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite,
    border: border(idle),
    enabledBorder: border(idle),
    disabledBorder: border(idle),
    focusedBorder: border(
      isDark ? AppColors.grey600 : AppColors.grey900,
      width: 1.5,
    ),
    errorBorder: border(Colors.red.shade400),
    focusedErrorBorder: border(Colors.red.shade400, width: 1.5),
    contentPadding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
  );
}

/// The full-width action button of a sign-in form, the same pill as the
/// provider buttons on the login page. Shows a spinner while [busy].
class LoginFormButton extends StatelessWidget {
  const LoginFormButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.onSurface,
          foregroundColor: scheme.surface,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.3),
          disabledForegroundColor: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        onPressed: busy ? null : onPressed,
        child:
            busy
                ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.surface,
                  ),
                )
                : Text(label),
      ),
    );
  }
}

/// Title and one line of explanation at the top of a sign-in form.
class LoginFormHeader extends StatelessWidget {
  const LoginFormHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

/// Closes the phone sign-in screen as soon as the person is signed in. It is
/// pushed over the login page or drawer rather than being a route the guard
/// knows, so nothing else would take it away.
mixin CloseWhenSignedIn<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Call from `build`.
  void closeWhenSignedIn() {
    ref.listen(authProvider, (_, next) {
      if (!next.isLoggedIn || next.isGuest || !mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }
}

/// Why the last Google or Apple sign-in failed, shown above the sign-in
/// buttons of the login page and drawer. Takes no space when there is nothing
/// to say (no failure, or the person cancelled).
class LoginErrorText extends StatelessWidget {
  const LoginErrorText({super.key, required this.reason});

  final LoginFailureReason? reason;

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    final text = reason == null ? null : loginFailureText(context.l10n, reason);
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// Puts a small "Last used" tag on the top edge of a sign-in button when
/// [show] is true: the method this phone last signed in with. After signing
/// out, or after the one-time sign-out when updating from an Auth0 build, it
/// keeps people from picking another method and landing in a new, empty
/// account.
///
/// It sits on the button's edge rather than inside it, so a long translated
/// label never has to make room.
class LastUsedTag extends StatelessWidget {
  const LastUsedTag({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          top: -9,
          end: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface,
              borderRadius: BorderRadius.circular(10),
              // Keeps it apart from a button of the same colour (Apple's).
              border: Border.all(
                color: theme.scaffoldBackgroundColor,
                width: 1.5,
              ),
            ),
            child: Text(
              context.l10n.login_last_used,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.surface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Widget for social login buttons
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/last_sign_in_method_provider.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/start_sign_in.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_form_widgets.dart';

class SocialLoginButton extends ConsumerWidget {
  const SocialLoginButton({
    super.key,
    required this.connection,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconWidget,
    required this.source,
    this.isBorder = false,
  });
  final String connection;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget iconWidget;
  final bool isBorder;
  final AuthSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side:
              isBorder
                  ? const BorderSide(color: Colors.black, width: 1)
                  : BorderSide.none,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        onPressed:
            () => startSignIn(
              context,
              ref,
              connection: connection,
              source: source,
            ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
    final lastUsed = ref.watch(lastSignInMethodProvider);
    return LastUsedTag(
      show: isLastUsedConnection(lastUsed, connection),
      child: button,
    );
  }
}
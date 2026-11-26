import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/my_practices_stats_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Practice tab with nothing in My practices yet: Home's "My practices"
/// pill reading "Start a routine", in the Next session spot, with one
/// helper line under it. A tap opens Edit routine; a guest is asked to
/// sign in first and then goes on to it.
class PracticeStartRoutinePill extends ConsumerWidget {
  const PracticeStartRoutinePill({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (ref.read(authProvider).isGuest) {
      await LoginDrawer.show(context, ref, feature: 'routine');
      if (!context.mounted || ref.read(authProvider).isGuest) return;
    }
    context.pushNamed('edit-routine');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyPracticesStatsCard(count: 0, onTap: () => _open(context, ref)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            context.l10n.practice_start_routine_hint,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color:
                  isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

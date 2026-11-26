import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/calendar/presentation/calendar_type_l10n.dart';
import 'package:flutter_pecha/features/calendar/presentation/providers/calendar_type_providers.dart';
import 'package:flutter_pecha/features/calendar/presentation/widgets/choose_calendar_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings row "Calendar   Tibetan (Phugpa) ›" that opens the calendar picker.
class CalendarTypeSettingsRow extends ConsumerWidget {
  const CalendarTypeSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final selected = ref.watch(selectedCalendarTypeProvider);

    return InkWell(
      onTap: () => ChooseCalendarSheet.show(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              AppAssets.calendarBlank,
              size: 24,
              color: theme.iconTheme.color,
            ),
            const SizedBox(width: 12),
            Text(l10n.settings_calendar_row, style: theme.textTheme.bodyLarge),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                calendarTypeLabel(l10n, selected),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(AppAssets.caretRight, size: 24, color: AppColors.grey600),
          ],
        ),
      ),
    );
  }
}

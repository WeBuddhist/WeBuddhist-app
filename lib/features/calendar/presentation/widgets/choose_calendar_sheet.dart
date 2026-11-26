import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/calendar/domain/models/calendar_type.dart';
import 'package:flutter_pecha/features/calendar/presentation/calendar_type_l10n.dart';
import 'package:flutter_pecha/features/calendar/presentation/providers/calendar_type_providers.dart';
import 'package:flutter_pecha/features/calendar/presentation/utils/calendar_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Choose calendar": the calendars on offer grouped under their tradition,
/// the current one checked. Picking one switches the calendar and closes.
class ChooseCalendarSheet extends ConsumerWidget {
  const ChooseCalendarSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const ChooseCalendarSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final selected = ref.watch(selectedCalendarTypeProvider);
    final choices = ref.watch(calendarTypeChoicesProvider);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.calendar_choose_calendar,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppAssets.x, size: 24),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
            Flexible(
              child: switch (choices) {
                AsyncData(:final value) => _ChoiceList(
                  traditions: value,
                  selected: selected,
                  onPick: (code) {
                    final from = ref.read(selectedCalendarTypeProvider);
                    if (from != code) {
                      ref
                          .read(calendarAnalyticsProvider)
                          .calendarTypeChanged(from: from, to: code);
                    }
                    ref
                        .read(selectedCalendarTypeProvider.notifier)
                        .select(code);
                    Navigator.of(context).pop();
                  },
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.traditions,
    required this.selected,
    required this.onPick,
  });

  final List<CalendarTradition> traditions;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final divider = Divider(
      height: 1,
      color: theme.dividerColor.withValues(alpha: 0.4),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        for (final tradition in traditions) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              calendarTraditionLabel(l10n, tradition.code),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (final type in tradition.types) ...[
            _CalendarOption(
              label: calendarTypeLabel(l10n, type),
              isSelected: type == selected,
              onTap: () => onPick(type),
            ),
            divider,
          ],
        ],
      ],
    );
  }
}

class _CalendarOption extends StatelessWidget {
  const _CalendarOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  AppAssets.check,
                  size: 18,
                  color: theme.colorScheme.onSurface,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

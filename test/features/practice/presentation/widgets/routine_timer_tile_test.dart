import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/routine_timer_tile.dart';
import 'package:flutter_pecha/features/timer/data/models/preset_timer_model.dart';
import 'package:flutter_pecha/features/timer/domain/entities/ambient_sound.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/providers/timers_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(RoutineItem item) => ProviderScope(
  overrides: [
    ambientSoundByIdProvider.overrideWith(
      (ref) => const {
        'rain': AmbientSound(id: 'rain', name: 'Rain', url: 'https://x/rain'),
      },
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: RoutineTimerTile(item: item)),
  ),
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  testWidgets('a linked user timer shows its title, duration and sound', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const RoutineItem(
          id: 'row-1',
          title: 'Study',
          type: RoutineItemType.timer,
          durationMs: 900000,
          timer: PresetTimerModel(
            id: 'timer-1',
            name: 'Study',
            description: 'Morning study',
            durationMs: 900000,
            type: kPresetTimerTypeUserCreated,
            ambientSoundId: 'rain',
          ),
        ),
      ),
    );

    expect(find.text('Morning study'), findsOneWidget);
    expect(find.text('15 ${en.timer_min}'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
  });

  testWidgets('a bare-duration timer shows only its duration', (tester) async {
    await tester.pumpWidget(
      _app(
        const RoutineItem(
          id: 'row-2',
          title: '',
          type: RoutineItemType.timer,
          durationMs: 600000,
        ),
      ),
    );

    expect(find.text('10 ${en.timer_min}'), findsOneWidget);
    expect(find.text(en.timer_ambient_sound_none), findsNothing);
  });
}

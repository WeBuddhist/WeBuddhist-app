import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresetTimer labels', () {
    test('under one minute counts seconds, so it never reads "0 min"', () {
      expect(PresetTimer.labelsInSeconds(20000), isTrue);
      expect(PresetTimer.formatDisplayValue(20000), '20 sec');
      expect(PresetTimer.formatDisplayValue(59000), '59 sec');
      expect(PresetTimer.hasUnitForMs(20000), isTrue);
      expect(
        PresetTimer.durationPartsFromMs(20000).single.unit,
        TimerDurationUnit.seconds,
      );
    });

    test('whole minutes stay minute labels', () {
      expect(PresetTimer.labelsInSeconds(60000), isFalse);
      expect(PresetTimer.formatDisplayValue(60000), '1 min');
      expect(PresetTimer.hasUnitForMs(60000), isTrue);
    });

    test('whole hours stay hour labels', () {
      expect(PresetTimer.formatDisplayValue(7200000), '2 hr');
      expect(PresetTimer.hasUnitForMs(7200000), isTrue);
      expect(
        PresetTimer.durationPartsFromMs(7200000).single.unit,
        TimerDurationUnit.hours,
      );
    });

    test('leftover seconds under an hour append sec to minutes', () {
      expect(PresetTimer.formatDisplayValue(89000), '1min 29sec');
      expect(PresetTimer.hasUnitForMs(89000), isFalse);
      expect(PresetTimer.formatDisplayValue(90000), '1min 30sec');
      expect(PresetTimer.formatDisplayValue(1294000), '21min 34sec');

      final leftover = PresetTimer.durationPartsFromMs(89000);
      expect(leftover, hasLength(2));
      expect(leftover[0].value, 1);
      expect(leftover[0].unit, TimerDurationUnit.minutes);
      expect(leftover[0].compact, isFalse);
      expect(leftover[1].value, 29);
      expect(leftover[1].unit, TimerDurationUnit.seconds);
      expect(leftover[1].compact, isTrue);
    });

    test('hours with leftover minutes and seconds use split units', () {
      expect(PresetTimer.formatDisplayValue(5040000), '1hr 24min');
      expect(PresetTimer.formatDisplayValue(5063000), '1hr 24min 23sec');
      expect(PresetTimer.formatDisplayValue(3934000), '1hr 5min 34sec');
      expect(PresetTimer.hasUnitForMs(3934000), isFalse);

      final hourWithSec = PresetTimer.durationPartsFromMs(5063000);
      expect(hourWithSec, hasLength(3));
      expect(hourWithSec[0].value, 1);
      expect(hourWithSec[0].unit, TimerDurationUnit.hours);
      expect(hourWithSec[1].value, 24);
      expect(hourWithSec[1].unit, TimerDurationUnit.minutes);
      expect(hourWithSec[2].value, 23);
      expect(hourWithSec[2].unit, TimerDurationUnit.seconds);
      expect(hourWithSec[2].compact, isTrue);
    });

    test('instance getters follow durationMs', () {
      const timer = PresetTimer(id: 't', name: '30 seconds', durationMs: 30000);
      expect(timer.displaysSeconds, isTrue);
      expect(timer.hasUnit, isTrue);
      expect(timer.displayValue, '30 sec');
    });

    test(
      'apiNameFromMs uses words for a single unit and short compound form',
      () {
        expect(PresetTimer.apiNameFromMs(20000), '20 seconds');
        expect(PresetTimer.apiNameFromMs(60000), '1 minutes');
        expect(PresetTimer.apiNameFromMs(7200000), '2 hours');
        expect(PresetTimer.apiNameFromMs(5063000), '1hr 24min 23sec');
      },
    );
  });

  group('PresetTimer sameSetup', () {
    test('same duration with different sound is not a duplicate', () {
      const timer1 = PresetTimer(
        id: '1',
        name: 'Timer 1',
        durationMs: 1260000,
        ambientSoundId: 'sound_1',
      );
      const timer2 = PresetTimer(
        id: '2',
        name: 'Timer 2',
        durationMs: 1260000,
        ambientSoundId: 'sound_2',
      );
      expect(timer1.sameSetup(timer2), isFalse);
    });

    test('blank sound matches null sound', () {
      const timerNull = PresetTimer(
        id: '1',
        name: 'Timer Null',
        durationMs: 1260000,
        ambientSoundId: null,
      );
      const timerBlank = PresetTimer(
        id: '2',
        name: 'Timer Blank',
        durationMs: 1260000,
        ambientSoundId: '  ',
      );
      const timerEmpty = PresetTimer(
        id: '3',
        name: 'Timer Empty',
        durationMs: 1260000,
        ambientSoundId: '',
      );

      expect(timerNull.sameSetup(timerBlank), isTrue);
      expect(timerNull.sameSetup(timerEmpty), isTrue);
      expect(timerBlank.sameSetup(timerEmpty), isTrue);
    });

    test('same duration and same sound is duplicate', () {
      const timer1 = PresetTimer(
        id: '1',
        name: 'Timer 1',
        durationMs: 1260000,
        ambientSoundId: 'sound_1',
      );
      const timer2 = PresetTimer(
        id: '2',
        name: 'Timer 2',
        durationMs: 1260000,
        ambientSoundId: 'sound_1',
      );
      expect(timer1.sameSetup(timer2), isTrue);
    });
    test(
      'same duration and sound with different titles is not a duplicate',
      () {
        const morning = PresetTimer(
          id: '1',
          name: '20 minutes',
          description: 'Morning',
          durationMs: 1200000,
          type: kPresetTimerTypeUserCreated,
        );
        const evening = PresetTimer(
          id: '2',
          name: '20 minutes',
          description: 'Evening',
          durationMs: 1200000,
          type: kPresetTimerTypeUserCreated,
        );
        expect(morning.sameSetup(evening), isFalse);
      },
    );

    test('blank and null titles match, and titles are trimmed', () {
      const untitled = PresetTimer(
        id: '1',
        name: '20 minutes',
        durationMs: 1200000,
        type: kPresetTimerTypeUserCreated,
      );
      const blank = PresetTimer(
        id: '2',
        name: '20 minutes',
        description: '  ',
        durationMs: 1200000,
        type: kPresetTimerTypeUserCreated,
      );
      const padded = PresetTimer(
        id: '3',
        name: '20 minutes',
        description: ' Morning ',
        durationMs: 1200000,
        type: kPresetTimerTypeUserCreated,
      );
      const trimmed = PresetTimer(
        id: '4',
        name: '20 minutes',
        description: 'Morning',
        durationMs: 1200000,
        type: kPresetTimerTypeUserCreated,
      );
      expect(untitled.sameSetup(blank), isTrue);
      expect(padded.sameSetup(trimmed), isTrue);
    });
  });
}

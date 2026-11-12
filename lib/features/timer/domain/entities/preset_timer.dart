/// Raw value of the `preset` timer type as returned by `GET /timers`.
///
/// Used to distinguish preset timers (shown in the "Preset timers" grid)
/// from user-created ones (shown in "Your timers") once the backend starts
/// returning the latter.
const String kPresetTimerTypePreset = 'preset';

/// Raw value of the `user_created` timer type as returned by `GET /timers`.
///
/// These are the timers a user has created themselves (via `POST
/// /timers/user`) and are shown in the "Your timers" section.
const String kPresetTimerTypeUserCreated = 'user_created';

enum TimerDurationUnit { hours, minutes, seconds }

/// One hours / minutes / seconds run in a timer list label.
///
/// [compact] is true for leftover seconds in a compound label, which the
/// list renders at a smaller number size than hours and minutes.
class TimerDurationPart {
  const TimerDurationPart({
    required this.value,
    required this.unit,
    this.compact = false,
  });

  final int value;
  final TimerDurationUnit unit;
  final bool compact;
}

class PresetTimer {
  const PresetTimer({
    required this.id,
    required this.name,
    required this.durationMs,
    this.userId,
    this.groupId,
    this.type = kPresetTimerTypePreset,
    this.description,
    this.ambientSoundId,
    this.bellAtStart = true,
    this.bellAtEnd = true,
    this.parentPresetId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int durationMs;

  /// Owner of the timer (present on user-created timers).
  final String? userId;

  /// Group this timer belongs to, if any.
  final String? groupId;

  /// e.g. `"preset"`. Kept as a raw string since the backend may introduce
  /// new values (e.g. `"custom"`) over time.
  final String type;

  final String? description;

  /// Id of the ambient sound to play during the session, if any. Resolving
  /// this to a playable asset/name requires a sound catalog that does not
  /// exist in the app yet.
  final String? ambientSoundId;

  final bool bellAtStart;
  final bool bellAtEnd;

  /// Id of the preset this timer was cloned/derived from, if any.
  final String? parentPresetId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether this is a stock preset (as opposed to a user-created timer).
  bool get isPreset => type == kPresetTimerTypePreset;

  /// Whether this is a timer the user created themselves.
  bool get isUserCreated => type == kPresetTimerTypeUserCreated;

  int get durationMinutes => durationMs ~/ 60000;

  /// Whether labels count seconds rather than minutes. Below one minute,
  /// rounding to minutes would read "0 min".
  static bool labelsInSeconds(int durationMs) =>
      durationMs < Duration.millisecondsPerMinute;

  /// Compact hours unit from the Figma list (`hr`). Not an l10n key —
  /// `timer_duration_hours` is the full word used by the duration picker.
  static const hoursUnit = 'hr';

  /// Hours, minutes, and leftover seconds for list labels, split from
  /// truncated whole seconds the same way the duration picker reads the
  /// wheels. Zero units are omitted (`1hr 23sec`, not `1hr 0min 23sec`).
  static List<TimerDurationPart> durationPartsFromMs(int durationMs) {
    final totalSeconds = durationMs ~/ Duration.millisecondsPerSecond;
    if (totalSeconds < 60) {
      return [
        TimerDurationPart(value: totalSeconds, unit: TimerDurationUnit.seconds),
      ];
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <TimerDurationPart>[];

    if (hours > 0) {
      parts.add(TimerDurationPart(value: hours, unit: TimerDurationUnit.hours));
    }
    if (minutes > 0) {
      parts.add(
        TimerDurationPart(value: minutes, unit: TimerDurationUnit.minutes),
      );
    }
    if (seconds > 0) {
      parts.add(
        TimerDurationPart(
          value: seconds,
          unit: TimerDurationUnit.seconds,
          compact: parts.isNotEmpty,
        ),
      );
    }
    return parts;
  }

  /// English short-unit label for tests and callers that cannot take l10n:
  /// `20 sec`, `1 min`, `2 hr`, `1hr 24min`, `1hr 24min 23sec`.
  static String formatDisplayValue(int durationMs) =>
      formatLabel(durationMs, minutes: 'min', seconds: 'sec');

  /// Joins [durationPartsFromMs] with the given unit strings.
  ///
  /// A single unit keeps a space (`1 min`). Compound labels concatenate
  /// each number to its unit (`1hr 24min 23sec`).
  static String formatLabel(
    int durationMs, {
    String hours = hoursUnit,
    required String minutes,
    required String seconds,
  }) {
    final parts = durationPartsFromMs(durationMs);
    final compound = parts.length > 1;
    return parts
        .map((part) {
          final unit = switch (part.unit) {
            TimerDurationUnit.hours => hours,
            TimerDurationUnit.minutes => minutes,
            TimerDurationUnit.seconds => seconds,
          };
          return compound ? '${part.value}$unit' : '${part.value} $unit';
        })
        .join(' ');
  }

  /// API `name` when the user changes duration: `20 seconds`, `21 minutes`,
  /// `2 hours`, or the compound short form `1hr 24min 23sec`.
  static String apiNameFromMs(int durationMs) {
    final parts = durationPartsFromMs(durationMs);
    if (parts.length == 1) {
      final part = parts.first;
      return switch (part.unit) {
        TimerDurationUnit.seconds => '${part.value} seconds',
        TimerDurationUnit.minutes => '${part.value} minutes',
        TimerDurationUnit.hours => '${part.value} hours',
      };
    }
    return formatDisplayValue(durationMs);
  }

  /// True when the label is a single unit (seconds under a minute, or whole
  /// minutes / hours with no leftover). Compound labels omit a trailing unit.
  static bool hasUnitForMs(int durationMs) =>
      durationPartsFromMs(durationMs).length == 1;

  /// See [labelsInSeconds].
  bool get displaysSeconds => labelsInSeconds(durationMs);

  /// See [formatDisplayValue].
  String get displayValue => formatDisplayValue(durationMs);

  /// See [durationPartsFromMs].
  List<TimerDurationPart> get durationParts => durationPartsFromMs(durationMs);

  /// See [hasUnitForMs].
  bool get hasUnit => hasUnitForMs(durationMs);

  /// Checks if another timer has the same duration and ambient sound.
  /// Null and blank ambientSoundId are treated as equal.
  bool sameSetup(PresetTimer other) {
    final sound1 = ambientSoundId?.trim() ?? '';
    final sound2 = other.ambientSoundId?.trim() ?? '';
    return durationMs == other.durationMs && sound1 == sound2;
  }
}

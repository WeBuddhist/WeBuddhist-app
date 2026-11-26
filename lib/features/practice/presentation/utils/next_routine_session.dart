import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';

/// The routine session that comes next at [now]: the first one today that
/// starts at or after the current minute, or, once every session today has
/// started, tomorrow's first. Sessions without items are skipped, as there
/// is nothing in them to practice. Null when no session has items.
///
/// Also returns the session's place in the time-sorted routine, which
/// My Practices reports in analytics.
({RoutineBlock block, int index})? nextRoutineSession(
  RoutineData routine,
  DateTime now,
) {
  final sorted = routine.sortedByTime.blocks;
  final nowMinutes = now.hour * 60 + now.minute;
  int? first;
  for (var i = 0; i < sorted.length; i++) {
    final block = sorted[i];
    if (block.items.isEmpty) continue;
    first ??= i;
    if (block.timeInMinutes >= nowMinutes) return (block: block, index: i);
  }
  if (first == null) return null;
  return (block: sorted[first], index: first);
}

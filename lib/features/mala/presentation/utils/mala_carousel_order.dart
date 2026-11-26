import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';

/// A count on [presetId] at [at], recorded on this device.
class MalaLastUsed extends Equatable {
  const MalaLastUsed({required this.presetId, required this.at});

  final String presetId;
  final DateTime at;

  @override
  List<Object?> get props => [presetId, at];
}

/// The mala carousel's order: mantras the user has counted on first, newest
/// first, then the never-used ones in the server's order.
///
/// [local] is the last count made here. Its preset's time is the later of
/// the server's `last_used_at` and [local], so a count that has not synced
/// yet still puts that preset first.
List<Mantra> latestUsedFirst(List<Mantra> mantras, {MalaLastUsed? local}) {
  DateTime? usedAt(Mantra m) {
    final server = m.lastUsedAt;
    if (local == null || local.presetId != m.presetId) return server;
    if (server == null) return local.at;
    return local.at.isAfter(server) ? local.at : server;
  }

  final indexed = [
    for (final (i, m) in mantras.indexed) (index: i, mantra: m, at: usedAt(m)),
  ];
  indexed.sort((a, b) {
    final x = a.at, y = b.at;
    if (x != null && y != null) {
      final byTime = y.compareTo(x);
      if (byTime != 0) return byTime;
    } else if (x != null) {
      return -1;
    } else if (y != null) {
      return 1;
    }
    return a.index.compareTo(b.index);
  });
  return [for (final e in indexed) e.mantra];
}

/// [mantras] in [pinnedIds] order, so a refresh updates each mantra's content
/// without moving the pages. Presets not in [pinnedIds] follow in the order
/// given, and pinned ids no longer present are dropped.
List<Mantra> inPinnedOrder(List<Mantra> mantras, List<String> pinnedIds) {
  final byId = {for (final m in mantras) m.presetId: m};
  final pinned = pinnedIds.toSet();
  return [
    for (final id in pinnedIds)
      if (byId[id] case final mantra?) mantra,
    for (final m in mantras)
      if (!pinned.contains(m.presetId)) m,
  ];
}

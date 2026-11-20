import 'dart:async';
import 'dart:convert';

import 'package:flutter_pecha/core/storage/preferences_service.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_carousel_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The preset the user last counted on in this app, per user.
///
/// The server's `last_used_at` only covers counts it has received, so taps
/// still waiting to sync (offline, or inside the sync debounce) are kept here
/// and win over an older server value when the carousel is ordered.
class MalaLastUsedStore {
  MalaLastUsedStore({
    required String? Function(String key) read,
    required Future<void> Function(String key, String value) write,
    DateTime Function()? now,
  }) : _read = read,
       _write = write,
       _now = now ?? DateTime.now;

  final String? Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  final DateTime Function() _now;

  /// The last write, so a tap on the same preset within [_minWriteGap] is not
  /// written again. Precise to that gap, which is far finer than the order
  /// needs.
  MalaLastUsed? _lastWritten;
  String? _lastWrittenUserId;
  static const _minWriteGap = Duration(seconds: 30);

  static String _key(String userId) =>
      '${StorageKeys.malaLastUsedPresetPrefix}$userId';

  /// The stored entry for [userId], or null if none or unreadable.
  MalaLastUsed? read(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    final raw = _read(_key(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final presetId = json['preset_id'] as String?;
      final at = DateTime.tryParse((json['at'] as String?) ?? '');
      if (presetId == null || presetId.isEmpty || at == null) return null;
      return MalaLastUsed(presetId: presetId, at: at);
    } catch (_) {
      return null;
    }
  }

  /// Records a count on [presetId] now.
  Future<void> record(String? userId, String presetId) async {
    if (userId == null || userId.isEmpty || presetId.isEmpty) return;
    final now = _now();
    final last = _lastWritten;
    if (last != null &&
        _lastWrittenUserId == userId &&
        last.presetId == presetId &&
        now.difference(last.at) < _minWriteGap) {
      return;
    }
    final entry = MalaLastUsed(presetId: presetId, at: now);
    _lastWritten = entry;
    _lastWrittenUserId = userId;
    await _write(
      _key(userId),
      jsonEncode({
        'preset_id': entry.presetId,
        'at': entry.at.toUtc().toIso8601String(),
      }),
    );
  }
}

final malaLastUsedStoreProvider = Provider<MalaLastUsedStore>((ref) {
  final prefs = SharedPreferencesService.instance;
  return MalaLastUsedStore(
    read: (key) => prefs.getSync<String>(key),
    write: (key, value) => prefs.set<String>(key, value),
  );
});

/// Notes a counted bead or added rounds on [presetId] for the current user.
void recordMalaPresetUsed(WidgetRef ref, String presetId) {
  unawaited(
    ref.read(malaLastUsedStoreProvider).record(malaUserIdSync(), presetId),
  );
}

import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/storage/preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which optional parts the Practice tab showed: the next routine session,
/// and "From your spaces".
typedef PracticeLayout = ({bool routine, bool spaces});

/// The Practice tab's layout the last time it settled, kept on the device
/// per account. On a later visit the tab opens on it straight away instead
/// of waiting for sign-in, the routine and the joined spaces to answer.
class PracticeLayoutMemory {
  PracticeLayoutMemory({
    required String? Function() userId,
    required Object? Function(String key) read,
    required Future<void> Function(String key, int value) write,
  }) : _userId = userId,
       _read = read,
       _write = write;

  final String? Function() _userId;
  final Object? Function(String key) _read;
  final Future<void> Function(String key, int value) _write;

  static const _routineBit = 1;
  static const _spacesBit = 2;

  String? _key() {
    final id = _userId();
    return id == null || id.isEmpty ? null : 'practice_layout_$id';
  }

  /// The remembered layout, or null when none is kept for this account.
  PracticeLayout? read() {
    final key = _key();
    if (key == null) return null;
    final value = _read(key);
    if (value is! int) return null;
    return (routine: value & _routineBit != 0, spaces: value & _spacesBit != 0);
  }

  Future<void> save(PracticeLayout layout) async {
    final key = _key();
    if (key == null) return;
    await _write(
      key,
      (layout.routine ? _routineBit : 0) | (layout.spaces ? _spacesBit : 0),
    );
  }
}

final practiceLayoutMemoryProvider = Provider<PracticeLayoutMemory>((ref) {
  final store = ref.watch(screenCacheStoreProvider);
  final prefs = SharedPreferencesService.instance;
  return PracticeLayoutMemory(
    userId: () => store.currentUserIdSync,
    read: prefs.getSync<Object>,
    write: (key, value) => prefs.set<int>(key, value),
  );
});

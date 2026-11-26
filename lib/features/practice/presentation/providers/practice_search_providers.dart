import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/storage/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Practice search's recent queries, newest first, kept on the device.
final practiceRecentSearchesProvider =
    StateNotifierProvider<PracticeRecentSearchesNotifier, List<String>>((ref) {
      return PracticeRecentSearchesNotifier(ref.watch(storageServiceProvider));
    });

class PracticeRecentSearchesNotifier extends StateNotifier<List<String>> {
  PracticeRecentSearchesNotifier(this._storage) : super(const []) {
    _load();
  }

  final StorageService _storage;

  static const _key = 'practice_recent_searches';
  static const maxCount = 10;

  Future<void> _load() async {
    try {
      final saved = await _storage.get<List<Object?>>(_key);
      if (!mounted || saved == null) return;
      state = saved.whereType<String>().take(maxCount).toList();
    } catch (_) {
      // A bad entry only costs the list; searching still works.
    }
  }

  /// Puts [query] first, dropping an earlier copy in any letter case.
  void add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();
    _save(
      [
        trimmed,
        ...state.where((q) => q.toLowerCase() != lower),
      ].take(maxCount).toList(),
    );
  }

  void remove(String query) {
    _save(state.where((q) => q != query).toList());
  }

  void _save(List<String> queries) {
    state = queries;
    _storage.set<List<String>>(_key, queries);
  }
}

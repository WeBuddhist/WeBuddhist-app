import 'package:flutter_pecha/core/storage/storage_service.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_search_providers.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements StorageService {
  final Map<String, Object?> values = {};

  @override
  Future<T?> get<T>(String key) async => values[key] as T?;

  @override
  Future<bool> set<T>(String key, T value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> delete(String key) async => values.remove(key) != null;

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);
}

void main() {
  test('newest first, a repeat moves up whatever its case', () async {
    final notifier = PracticeRecentSearchesNotifier(_MemoryStorage());
    await Future<void>.delayed(Duration.zero);
    notifier
      ..add('Green Tara')
      ..add('Heart Sutra')
      ..add('green tara ');
    expect(notifier.state, ['green tara', 'Heart Sutra']);
  });

  test('keeps the last ten and saves them', () async {
    final storage = _MemoryStorage();
    final notifier = PracticeRecentSearchesNotifier(storage);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 12; i++) {
      notifier.add('query $i');
    }
    expect(notifier.state, hasLength(PracticeRecentSearchesNotifier.maxCount));
    expect(notifier.state.first, 'query 11');
    expect(storage.values['practice_recent_searches'], notifier.state);
  });

  test('loads what was saved, and remove drops one', () async {
    final storage =
        _MemoryStorage()
          ..values['practice_recent_searches'] = ['Refuge', 'Mani'];
    final notifier = PracticeRecentSearchesNotifier(storage);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, ['Refuge', 'Mani']);
    notifier.remove('Refuge');
    expect(notifier.state, ['Mani']);
  });
}

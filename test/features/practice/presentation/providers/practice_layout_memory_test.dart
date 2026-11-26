import 'package:flutter_pecha/features/practice/presentation/providers/practice_layout_memory.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PracticeLayoutMemory _memory(Map<String, Object?> values, String? userId) {
  return PracticeLayoutMemory(
    userId: () => userId,
    read: (key) => values[key],
    write: (key, value) async => values[key] = value,
  );
}

void main() {
  group('PracticeLayoutMemory', () {
    test('keeps each layout per account', () async {
      final values = <String, Object?>{};
      final a = _memory(values, 'a');
      final b = _memory(values, 'b');

      expect(a.read(), isNull);
      await a.save((routine: true, spaces: false));
      await b.save((routine: false, spaces: true));

      expect(a.read(), (routine: true, spaces: false));
      expect(b.read(), (routine: false, spaces: true));
      await a.save((routine: false, spaces: false));
      expect(a.read(), (routine: false, spaces: false));
    });

    test('keeps nothing without a signed-in account', () async {
      final values = <String, Object?>{};
      final memory = _memory(values, null);
      await memory.save((routine: true, spaces: true));
      expect(values, isEmpty);
      expect(memory.read(), isNull);
    });

    test('ignores a stored value of another type', () {
      final memory = _memory({'practice_layout_a': 'grouped'}, 'a');
      expect(memory.read(), isNull);
    });
  });

  group('practiceLayoutPending', () {
    test('first load and reloads are pending, pull-to-refresh is not', () {
      expect(practiceLayoutPending(const AsyncLoading<int>()), isTrue);
      expect(practiceLayoutPending(const AsyncData(1)), isFalse);
      // Read again after sign-in or the language changed.
      expect(
        practiceLayoutPending(
          const AsyncLoading<int>().copyWithPrevious(
            const AsyncData(1),
            isRefresh: false,
          ),
        ),
        isTrue,
      );
      // ref.invalidate / ref.refresh from pull-to-refresh.
      expect(
        practiceLayoutPending(
          const AsyncLoading<int>().copyWithPrevious(
            const AsyncData(1),
            isRefresh: true,
          ),
        ),
        isFalse,
      );
    });
  });
}

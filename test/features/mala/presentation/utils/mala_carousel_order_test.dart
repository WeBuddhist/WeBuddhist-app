import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_carousel_order.dart';
import 'package:flutter_test/flutter_test.dart';

Mantra _m(String id, [DateTime? lastUsedAt]) =>
    Mantra(presetId: id, lastUsedAt: lastUsedAt);

List<String> _ids(List<Mantra> mantras) => [
  for (final m in mantras) m.presetId,
];

void main() {
  final t1 = DateTime.utc(2026, 11, 18, 7);
  final t2 = DateTime.utc(2026, 11, 19, 7);
  final t3 = DateTime.utc(2026, 11, 20, 7);

  group('latestUsedFirst', () {
    test('used newest first, then never-used in server order', () {
      final ordered = latestUsedFirst([
        _m('a'),
        _m('b', t1),
        _m('c'),
        _m('d', t3),
        _m('e', t2),
        _m('f'),
      ]);
      expect(_ids(ordered), ['d', 'e', 'b', 'a', 'c', 'f']);
    });

    test('nothing used keeps the server order', () {
      expect(_ids(latestUsedFirst([_m('a'), _m('b'), _m('c')])), [
        'a',
        'b',
        'c',
      ]);
    });

    test('equal times keep the server order', () {
      expect(_ids(latestUsedFirst([_m('a', t1), _m('b', t1)])), ['a', 'b']);
    });

    test('a newer local count wins over the server value', () {
      final ordered = latestUsedFirst(
        [_m('a', t3), _m('b', t1)],
        local: MalaLastUsed(
          presetId: 'b',
          at: t3.add(const Duration(minutes: 1)),
        ),
      );
      expect(_ids(ordered), ['b', 'a']);
    });

    test('a local count makes a never-used preset used', () {
      final ordered = latestUsedFirst([
        _m('a', t1),
        _m('b'),
      ], local: MalaLastUsed(presetId: 'b', at: t2));
      expect(_ids(ordered), ['b', 'a']);
    });

    test('an older local count does not pull a preset back', () {
      final ordered = latestUsedFirst([
        _m('a', t2),
        _m('b', t3),
      ], local: MalaLastUsed(presetId: 'b', at: t1));
      expect(_ids(ordered), ['b', 'a'], reason: 'b keeps its server time');
    });

    test('a local count on a preset not in the list is ignored', () {
      final ordered = latestUsedFirst([
        _m('a'),
        _m('b', t1),
      ], local: MalaLastUsed(presetId: 'gone', at: t3));
      expect(_ids(ordered), ['b', 'a']);
    });
  });

  group('inPinnedOrder', () {
    test('keeps the pinned order and takes the new content', () {
      final refreshed = [
        const Mantra(presetId: 'a', targetCount: 1),
        const Mantra(presetId: 'b', targetCount: 2),
        const Mantra(presetId: 'c', targetCount: 3),
      ];
      final ordered = inPinnedOrder(refreshed, ['c', 'a', 'b']);
      expect(_ids(ordered), ['c', 'a', 'b']);
      expect(ordered.first.targetCount, 3);
    });

    test('new presets go at the end and removed ones are dropped', () {
      final ordered = inPinnedOrder(
        [_m('x'), _m('a'), _m('y'), _m('c')],
        ['c', 'b', 'a'],
      );
      expect(_ids(ordered), ['c', 'a', 'x', 'y']);
    });
  });

  test('lastUsedAt does not change a mantra\'s identity', () {
    // A Mantra keys malaCounterProvider; a refresh that only moves
    // lastUsedAt must not restart the counter.
    expect(_m('a', t1), _m('a', t2));
    expect(_m('a', t1).hashCode, _m('a').hashCode);
  });
}

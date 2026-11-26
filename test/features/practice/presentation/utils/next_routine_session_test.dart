import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/next_routine_session.dart';
import 'package:flutter_test/flutter_test.dart';

RoutineBlock _block(String id, int hour, {bool empty = false}) => RoutineBlock(
  id: id,
  time: TimeOfDay(hour: hour, minute: 0),
  items:
      empty
          ? const []
          : [
            RoutineItem(id: '$id-item', title: id, type: RoutineItemType.plan),
          ],
);

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 24, hour, minute);

void main() {
  // Out of order on purpose: the routine is sorted before choosing.
  final routine = RoutineData(
    blocks: [_block('evening', 20), _block('morning', 6), _block('noon', 16)],
  );

  test('picks the next session to start today', () {
    final next = nextRoutineSession(routine, _at(15))!;
    expect(next.block.id, 'noon');
    expect(next.index, 1);
  });

  test('a session starting this minute is still next', () {
    expect(nextRoutineSession(routine, _at(16))!.block.id, 'noon');
    expect(nextRoutineSession(routine, _at(16, 1))!.block.id, 'evening');
  });

  test('wraps to tomorrow\'s first session after the last one', () {
    final next = nextRoutineSession(routine, _at(22))!;
    expect(next.block.id, 'morning');
    expect(next.index, 0);
  });

  test('skips sessions with no items', () {
    final withEmpty = RoutineData(
      blocks: [_block('morning', 6, empty: true), _block('evening', 20)],
    );
    expect(nextRoutineSession(withEmpty, _at(5))!.block.id, 'evening');
    expect(nextRoutineSession(withEmpty, _at(21))!.block.id, 'evening');
  });

  test('null when no session has items', () {
    final empty = RoutineData(blocks: [_block('a', 6, empty: true)]);
    expect(nextRoutineSession(empty, _at(5)), isNull);
    expect(nextRoutineSession(const RoutineData(), _at(5)), isNull);
  });
}

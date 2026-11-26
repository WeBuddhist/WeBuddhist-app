import 'package:flutter_pecha/features/group_chat/presentation/utils/prayer_board_access.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 17, 12);

  GroupEvent event({
    DateTime? start,
    DateTime? end,
    bool isRecurring = false,
  }) {
    return GroupEvent(
      id: 'e1',
      groupId: 'g1',
      title: 'Puja',
      startDate: start,
      endDate: end,
      isRecurring: isRecurring,
    );
  }

  test('a space, or an event still loading, is open', () {
    expect(prayerBoardTakesRequests(event: null, now: now), isTrue);
  });

  test('an event that has not ended is open', () {
    final e = event(
      start: now.subtract(const Duration(hours: 1)),
      end: now.add(const Duration(hours: 1)),
    );
    expect(prayerBoardTakesRequests(event: e, now: now), isTrue);
  });

  test('an upcoming event is open', () {
    final e = event(
      start: now.add(const Duration(days: 2)),
      end: now.add(const Duration(days: 2, hours: 2)),
    );
    expect(prayerBoardTakesRequests(event: e, now: now), isTrue);
  });

  test('an event past its end is closed', () {
    final e = event(
      start: now.subtract(const Duration(days: 1)),
      end: now.subtract(const Duration(hours: 22)),
    );
    expect(prayerBoardTakesRequests(event: e, now: now), isFalse);
  });

  test('closes at the very moment the event ends', () {
    final e = event(start: now.subtract(const Duration(hours: 2)), end: now);
    expect(prayerBoardTakesRequests(event: e, now: now), isFalse);
  });

  test('an event with no end of its own closes six hours after start', () {
    final start = now.subtract(const Duration(hours: 6));
    expect(prayerBoardTakesRequests(event: event(start: start), now: now), isFalse);
    expect(
      prayerBoardTakesRequests(
        event: event(start: start.add(const Duration(minutes: 1))),
        now: now,
      ),
      isTrue,
    );
  });

  test('an event with no dates stays open', () {
    expect(prayerBoardTakesRequests(event: event(), now: now), isTrue);
  });

  test('a recurring event stays open, even past the dates it carries', () {
    // The API sends the next occurrence's dates, never a series end.
    final e = event(
      start: now.subtract(const Duration(days: 7)),
      end: now.subtract(const Duration(days: 7)).add(const Duration(hours: 1)),
      isRecurring: true,
    );
    expect(prayerBoardTakesRequests(event: e, now: now), isTrue);
  });
}

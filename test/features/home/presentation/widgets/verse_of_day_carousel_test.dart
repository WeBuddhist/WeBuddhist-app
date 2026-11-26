import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_carousel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int pageAfter(List<String> oldIds, List<String> newIds, int page) =>
      verseCarouselPageAfterUpdate(oldIds: oldIds, newIds: newIds, page: page);

  test('a new day moves the shown verse along with it', () {
    // On Tuesday's card when Thursday arrives at the front.
    expect(pageAfter(['wed', 'tue', 'mon'], ['thu', 'wed', 'tue'], 1), 2);
    // On today's card: stays on it, now yesterday.
    expect(pageAfter(['wed', 'tue'], ['thu', 'wed', 'tue'], 0), 1);
  });

  test('an unchanged week keeps the page', () {
    expect(pageAfter(['b', 'a'], ['b', 'a'], 1), 1);
  });

  test('a shown verse that drops out keeps its index, kept in range', () {
    expect(pageAfter(['c', 'b', 'a'], ['c', 'a'], 1), 1);
    // The oldest day fell out of the week while it was showing.
    expect(pageAfter(['d', 'c', 'b', 'a'], ['e', 'd', 'c'], 3), 2);
  });

  test('an empty week goes back to the first page', () {
    expect(pageAfter(['a'], [], 0), 0);
  });
}

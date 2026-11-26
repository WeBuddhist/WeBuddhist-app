import 'package:flutter_pecha/features/connect/domain/entities/connect_feed_item.dart';
import 'package:flutter_pecha/features/home/presentation/utils/home_feed_rows.dart';
import 'package:flutter_test/flutter_test.dart';

List<ConnectFeedItem> _items(int count) => [
  for (var i = 0; i < count; i++)
    ConnectFeedItem(
      type: ConnectFeedItemType.event,
      groupId: 'g$i',
      groupName: 'Group $i',
    ),
];

/// `0`..`n` for cards, `P` for poems, `S` for share.
String _shape(List<HomeFeedRow> rows) => rows
    .map(
      (row) => switch (row) {
        HomeFeedItemRow(:final position) => '$position',
        HomeFeedPoemsRow() => 'P',
        HomeFeedShareRow() => 'S',
      },
    )
    .join(' ');

void main() {
  test('poems after the 4th card and share after the 8th, once each', () {
    expect(
      _shape(buildHomeFeedRows(_items(12), feedEnded: false)),
      '0 1 2 3 P 4 5 6 7 S 8 9 10 11',
    );
    expect(
      _shape(buildHomeFeedRows(_items(12), feedEnded: true)),
      '0 1 2 3 P 4 5 6 7 S 8 9 10 11',
    );
  });

  test('exactly 8 cards places both without repeating them', () {
    expect(
      _shape(buildHomeFeedRows(_items(8), feedEnded: true)),
      '0 1 2 3 P 4 5 6 7 S',
    );
  });

  test('a short feed that ended gets the rest at its end', () {
    expect(
      _shape(buildHomeFeedRows(_items(6), feedEnded: true)),
      '0 1 2 3 P 4 5 S',
    );
    expect(_shape(buildHomeFeedRows(_items(2), feedEnded: true)), '0 1 P S');
    expect(_shape(buildHomeFeedRows(const [], feedEnded: true)), 'P S');
  });

  test('a short feed still paging holds them back', () {
    expect(
      _shape(buildHomeFeedRows(_items(6), feedEnded: false)),
      '0 1 2 3 P 4 5',
    );
    expect(_shape(buildHomeFeedRows(_items(2), feedEnded: false)), '0 1');
    expect(buildHomeFeedRows(const [], feedEnded: false), isEmpty);
  });

  test('cards keep their feed position and item', () {
    final items = _items(5);
    final cards =
        buildHomeFeedRows(items, feedEnded: false)
            .whereType<HomeFeedItemRow>()
            .toList();
    expect(cards.map((row) => row.position), [0, 1, 2, 3, 4]);
    expect(cards.map((row) => row.item), items);
  });
}

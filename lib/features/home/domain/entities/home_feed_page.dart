import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/connect/domain/entities/connect_feed_item.dart';

/// Where the next page of Home's feed starts. Members page `/feed` by
/// cursor, guests page the public spaces feed by offset.
sealed class HomeFeedPageToken extends Equatable {
  const HomeFeedPageToken();
}

/// `next_cursor` from a `/feed` page.
final class HomeFeedCursor extends HomeFeedPageToken {
  const HomeFeedCursor(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

/// `skip` for the next page of the public spaces feed.
final class HomeFeedOffset extends HomeFeedPageToken {
  const HomeFeedOffset(this.skip);

  final int skip;

  @override
  List<Object?> get props => [skip];
}

/// One page of Home's feed: posts and events only, in server order.
class HomeFeedPage {
  const HomeFeedPage({required this.items, this.next});

  final List<ConnectFeedItem> items;

  /// Null on the last page.
  final HomeFeedPageToken? next;

  bool get hasMore => next != null;
}

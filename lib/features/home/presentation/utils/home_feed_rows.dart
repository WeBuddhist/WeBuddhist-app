import 'package:flutter_pecha/features/connect/domain/entities/connect_feed_item.dart';

/// One row of Home's feed list.
sealed class HomeFeedRow {
  const HomeFeedRow();
}

/// A post or event card. [position] counts feed cards only, for analytics.
final class HomeFeedItemRow extends HomeFeedRow {
  const HomeFeedItemRow(this.item, this.position);

  final ConnectFeedItem item;
  final int position;
}

/// The poems carousel.
final class HomeFeedPoemsRow extends HomeFeedRow {
  const HomeFeedPoemsRow();
}

/// "Enjoying WeBuddhist?" with Share and Feedback.
final class HomeFeedShareRow extends HomeFeedRow {
  const HomeFeedShareRow();
}

/// Feed cards that come before the poems carousel.
const int homeFeedPoemsAfter = 4;

/// Feed cards that come before the share block.
const int homeFeedShareAfter = 8;

/// Home's feed with poems after the 4th card and the share block after the
/// 8th, each shown once.
///
/// A feed with fewer cards gets them at its end, but only once [feedEnded]
/// (no more pages, or nothing left to wait for). Until then they are held
/// back, so they don't show at the end and then jump down as cards load.
List<HomeFeedRow> buildHomeFeedRows(
  List<ConnectFeedItem> items, {
  required bool feedEnded,
  int poemsAfter = homeFeedPoemsAfter,
  int shareAfter = homeFeedShareAfter,
}) {
  final rows = <HomeFeedRow>[];
  var poemsShown = false;
  var shareShown = false;

  for (var i = 0; i < items.length; i++) {
    rows.add(HomeFeedItemRow(items[i], i));
    final count = i + 1;
    if (count == poemsAfter) {
      rows.add(const HomeFeedPoemsRow());
      poemsShown = true;
    }
    if (count == shareAfter) {
      rows.add(const HomeFeedShareRow());
      shareShown = true;
    }
  }

  if (feedEnded) {
    if (!poemsShown) rows.add(const HomeFeedPoemsRow());
    if (!shareShown) rows.add(const HomeFeedShareRow());
  }
  return rows;
}

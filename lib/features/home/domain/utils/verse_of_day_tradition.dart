/// Tradition codes as `GET /traditions` names them.
abstract final class TraditionCodes {
  static const theravada = 'pali';
  static const mahayana = 'chinese';
  static const vajrayana = 'tibetan';
}

/// Which tradition's Verse of the Day a user following several gets: the
/// first of these they follow (Theravada, then Vajrayana, then Mahayana).
const verseOfDayTraditionPriority = [
  TraditionCodes.theravada,
  TraditionCodes.vajrayana,
  TraditionCodes.mahayana,
];

/// The tradition to ask `/verse-of-day` for, or null to leave `tradition`
/// out (guests, no traditions saved), which gets the All traditions verse.
///
/// Sent explicitly because the backend's own pick for several traditions is
/// the most recently followed one, not [verseOfDayTraditionPriority].
String? verseOfDayTradition(Iterable<String> followedCodes) {
  final followed = followedCodes.toSet();
  for (final code in verseOfDayTraditionPriority) {
    if (followed.contains(code)) return code;
  }
  return null;
}

/// Which sections the Chants page shows, in order, for a pill and the data
/// at hand. Kept free of widgets so the layout rules can be tested alone.
library;

import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';

/// The pills at the top of the Chants page.
enum ChantsFilter { all, chantBooks, singleChants }

enum ChantsSection {
  /// "My chant books" rail.
  myChantBooks,

  /// "From your spaces" group heading.
  yourSpacesHeading,

  /// Chant books from spaces the user joined.
  yourSpaceChantBooks,

  /// Chants with recordings from spaces the user joined.
  yourAudioChants,

  /// Chants without recordings from spaces the user joined.
  yourTextChants,

  /// "Explore more" group heading.
  exploreMoreHeading,

  /// Chant books from other public spaces.
  otherSpaceChantBooks,

  /// Chants with recordings from other public spaces; "Audio chants" for a
  /// new user.
  otherAudioChants,

  /// Text-only chants from other spaces, then the library's: a short list
  /// under All, the full paged list under Single chants.
  textOnlyChants,
}

/// The design's layouts:
/// - With chant books in the user's spaces, space content is grouped under
///   "From your spaces" and "Explore more" (All and Single chants pills).
/// - Without (a new user), the same sections show with no group headings.
/// - The Chant books pill has no group headings either: "From your spaces"
///   and "Explore more" title the two rails themselves.
/// - Empty sections are left out; a heading with nothing under it too, and
///   "Explore more" only follows a "From your spaces" group.
///
/// Library chants belong to no space, so they sit under "Explore more".
List<ChantsSection> chantsPageSections({
  required ChantsFilter filter,
  required bool hasMyChantBooks,
  required bool hasYourSpaceChantBooks,
  required bool hasOtherSpaceChantBooks,
  required bool hasTextOnlyChants,
  bool hasYourAudioChants = false,
  bool hasOtherAudioChants = false,
  bool hasYourTextChants = false,
}) {
  final books = filter != ChantsFilter.singleChants;
  final singles = filter != ChantsFilter.chantBooks;
  final grouped = singles && hasYourSpaceChantBooks;
  final yours = [
    if (books && hasYourSpaceChantBooks) ChantsSection.yourSpaceChantBooks,
    if (singles && hasYourAudioChants) ChantsSection.yourAudioChants,
    if (singles && hasYourTextChants) ChantsSection.yourTextChants,
  ];
  final explore = [
    if (books && hasOtherSpaceChantBooks) ChantsSection.otherSpaceChantBooks,
    if (singles && hasOtherAudioChants) ChantsSection.otherAudioChants,
    if (singles && hasTextOnlyChants) ChantsSection.textOnlyChants,
  ];
  return [
    if (books && hasMyChantBooks) ChantsSection.myChantBooks,
    if (grouped && yours.isNotEmpty) ChantsSection.yourSpacesHeading,
    ...yours,
    if (grouped && yours.isNotEmpty && explore.isNotEmpty)
      ChantsSection.exploreMoreHeading,
    ...explore,
  ];
}

/// Text-only chants listed under All before "See all".
const int chantsAllTextOnlyLimit = 3;

/// Chants with audio, and your spaces' text-only chants, listed before
/// "See all": 3 under All, 4 under Single chants.
int chantsRowLimit(ChantsFilter filter) =>
    filter == ChantsFilter.singleChants ? 4 : 3;

/// Shortest search query that runs, matching the chant search.
const int chantsSearchMinQueryLength = 3;

/// Chant books whose name or subtitle (space or owner) contains [query],
/// ignoring case and surrounding spaces. Space books have no server search
/// yet (Q6), and the whole feed is already loaded, so they are matched here.
List<T> matchChantBooks<T>(
  Iterable<T> books,
  String query, {
  required String Function(T) name,
  required String? Function(T) subtitle,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return books.where((book) {
    if (name(book).toLowerCase().contains(needle)) return true;
    return subtitle(book)?.toLowerCase().contains(needle) ?? false;
  }).toList();
}

/// Space chants whose title or space name contains [query], your spaces
/// first: `audio` with recordings, `text` without.
({List<SpaceChant> audio, List<SpaceChant> text}) matchSpaceChants(
  SpaceChants chants,
  String query,
) {
  List<SpaceChant> match(List<SpaceChant> list) => matchChantBooks(
    list,
    query,
    name: (c) => c.item.title,
    subtitle: (c) => c.spaceName,
  );
  return (
    audio: [...match(chants.yoursAudio), ...match(chants.othersAudio)],
    text: [...match(chants.yoursText), ...match(chants.othersText)],
  );
}

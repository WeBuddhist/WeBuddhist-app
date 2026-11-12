import 'package:equatable/equatable.dart';

/// Where a chant book on the Chants page comes from; decides which screen
/// opens it.
enum ChantBookSource {
  /// The user's own or imported collection (`/users/me/recitation-collections`).
  personal,

  /// A space's collection, from the practices feed.
  space,
}

/// One chant book card on the Chants page, whichever API it came from.
class ChantBook extends Equatable {
  const ChantBook({
    required this.id,
    required this.name,
    required this.source,
    this.imageUrl,
    this.chantCount = 0,
    this.audioItemCount = 0,
    this.subtitle,
    this.groupId,
    this.groupAvatarUrl,
    this.isJoinedSpace = false,
  });

  final String id;
  final String name;
  final ChantBookSource source;
  final String? imageUrl;
  final int chantCount;

  /// 0 until the backend sends `audio_item_count` (Q2).
  final int audioItemCount;

  /// Space name, or the owner of an imported book; null for the user's own.
  final String? subtitle;
  final String? groupId;
  final String? groupAvatarUrl;
  final bool isJoinedSpace;

  bool get hasAudio => audioItemCount > 0;

  @override
  List<Object?> get props => [
    id,
    name,
    source,
    imageUrl,
    chantCount,
    audioItemCount,
    subtitle,
    groupId,
    groupAvatarUrl,
    isJoinedSpace,
  ];
}

/// One page of the user's chant books.
class ChantBooksPage extends Equatable {
  const ChantBooksPage({
    required this.books,
    required this.skip,
    required this.total,
  });

  static const empty = ChantBooksPage(books: [], skip: 0, total: 0);

  final List<ChantBook> books;
  final int skip;
  final int total;

  bool get hasMore => skip + books.length < total;

  @override
  List<Object?> get props => [books, skip, total];
}

/// Space chant books split into the user's spaces and everyone else's.
class SpaceChantBooks extends Equatable {
  const SpaceChantBooks({this.yours = const [], this.others = const []});

  static const empty = SpaceChantBooks();

  final List<ChantBook> yours;
  final List<ChantBook> others;

  /// The design's "new user" layout applies when the user's spaces have no
  /// chant books: no Your / Other split, no toggle.
  bool get hasYourSpaces => yours.isNotEmpty;

  @override
  List<Object?> get props => [yours, others];
}

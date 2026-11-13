import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';

/// One chant inside a space chant book, shown as a single chant row.
///
/// Keeps the whole [collection] so opening it can build the same reader
/// context as the space's chant book screen (next / previous chant, audio).
class SpaceChant extends Equatable {
  const SpaceChant({
    required this.item,
    required this.collection,
    this.spaceName,
    this.groupAvatarUrl,
    this.isJoinedSpace = false,
  });

  final GroupRecitationCollectionItem item;
  final GroupRecitationCollection collection;
  final String? spaceName;
  final String? groupAvatarUrl;
  final bool isJoinedSpace;

  /// Item audio is already limited to playable recordings by the model.
  bool get hasAudio => item.audio.isNotEmpty;

  @override
  List<Object?> get props => [
    item,
    collection.id,
    spaceName,
    groupAvatarUrl,
    isJoinedSpace,
  ];
}

/// Chants from space chant books, split by joined space and by audio.
class SpaceChants extends Equatable {
  const SpaceChants({
    this.yoursAudio = const [],
    this.yoursText = const [],
    this.othersAudio = const [],
    this.othersText = const [],
    this.failedBookCount = 0,
  });

  static const empty = SpaceChants();

  final List<SpaceChant> yoursAudio;
  final List<SpaceChant> yoursText;
  final List<SpaceChant> othersAudio;
  final List<SpaceChant> othersText;

  /// Chant books whose chants could not be read, so the lists above are
  /// missing them; the page says so and offers a retry.
  final int failedBookCount;

  bool get isPartial => failedBookCount > 0;

  /// Only the chants in [languageCode] (the Chants page language). Compared
  /// on the main language tag, so `zh` matches `zh-Hant`; a chant with no
  /// language is kept.
  SpaceChants inLanguage(String languageCode) {
    final wanted = _mainTag(languageCode);
    if (wanted.isEmpty) return this;
    List<SpaceChant> keep(List<SpaceChant> chants) =>
        chants.where((chant) {
          final language = _mainTag(chant.item.language);
          return language.isEmpty || language == wanted;
        }).toList();
    return SpaceChants(
      yoursAudio: keep(yoursAudio),
      yoursText: keep(yoursText),
      othersAudio: keep(othersAudio),
      othersText: keep(othersText),
      failedBookCount: failedBookCount,
    );
  }

  static String _mainTag(String code) =>
      code.trim().toLowerCase().split(RegExp('[-_]')).first;

  bool get isEmpty =>
      yoursAudio.isEmpty &&
      yoursText.isEmpty &&
      othersAudio.isEmpty &&
      othersText.isEmpty;

  @override
  List<Object?> get props => [
    yoursAudio,
    yoursText,
    othersAudio,
    othersText,
    failedBookCount,
  ];
}

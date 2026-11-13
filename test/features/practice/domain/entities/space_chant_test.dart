import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_test/flutter_test.dart';

const _book = GroupRecitationCollection(id: 'b', groupId: 'g', name: 'B');

SpaceChant _chant(String title, String language) => SpaceChant(
  item: GroupRecitationCollectionItem(
    id: title,
    textId: title,
    title: title,
    language: language,
    type: '',
    displayOrder: 0,
  ),
  collection: _book,
);

List<String> _titles(List<SpaceChant> chants) =>
    chants.map((c) => c.item.title).toList();

void main() {
  group('SpaceChants.inLanguage', () {
    final chants = SpaceChants(
      yoursAudio: [_chant('Tara bo', 'bo'), _chant('Tara en', 'en')],
      yoursText: [_chant('Refuge zh', 'zh-Hant')],
      othersAudio: [_chant('Heart en', 'EN')],
      othersText: [_chant('No language', ''), _chant('Monday bo', 'bo')],
    );

    test('keeps chants in the language in every list', () {
      final bo = chants.inLanguage('bo');
      expect(_titles(bo.yoursAudio), ['Tara bo']);
      expect(bo.yoursText, isEmpty);
      expect(bo.othersAudio, isEmpty);
      expect(_titles(bo.othersText), ['No language', 'Monday bo']);
    });

    test('matches on the main tag, ignoring case', () {
      expect(_titles(chants.inLanguage('zh').yoursText), ['Refuge zh']);
      expect(_titles(chants.inLanguage('en').othersAudio), ['Heart en']);
    });

    test('a blank language keeps everything', () {
      expect(chants.inLanguage(' '), chants);
    });

    test('keeps the count of books that failed to load', () {
      final partial = SpaceChants(
        yoursAudio: [_chant('Tara bo', 'bo')],
        failedBookCount: 2,
      );
      expect(partial.isPartial, isTrue);
      expect(partial.inLanguage('en').failedBookCount, 2);
      expect(SpaceChants.empty.isPartial, isFalse);
    });
  });
}

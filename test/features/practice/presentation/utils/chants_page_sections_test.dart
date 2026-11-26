import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_sections.dart';
import 'package:flutter_test/flutter_test.dart';

List<ChantsSection> _sections(
  ChantsFilter filter, {
  bool my = false,
  bool yours = false,
  bool others = false,
  bool yourChants = false,
  bool otherChants = false,
}) => chantsPageSections(
  filter: filter,
  hasMyChantBooks: my,
  hasYourSpaceChantBooks: yours,
  hasOtherSpaceChantBooks: others,
  hasYourChants: yourChants,
  hasOtherChants: otherChants,
);

void main() {
  group('All', () {
    test('groups space content when the user has space chant books', () {
      expect(
        _sections(
          ChantsFilter.all,
          my: true,
          yours: true,
          others: true,
          yourChants: true,
          otherChants: true,
        ),
        [
          ChantsSection.myChantBooks,
          ChantsSection.yourSpacesHeading,
          ChantsSection.yourSpaceChantBooks,
          ChantsSection.yourChants,
          ChantsSection.exploreMoreHeading,
          ChantsSection.otherSpaceChantBooks,
          ChantsSection.otherChants,
        ],
        reason: 'audio and text-only chants share one list per group',
      );
    });

    test('a new user gets the sections with no group headings', () {
      expect(_sections(ChantsFilter.all, others: true, otherChants: true), [
        ChantsSection.otherSpaceChantBooks,
        ChantsSection.otherChants,
      ]);
    });

    test('drops "Explore more" when nothing sits under it', () {
      expect(_sections(ChantsFilter.all, yours: true), [
        ChantsSection.yourSpacesHeading,
        ChantsSection.yourSpaceChantBooks,
      ]);
    });

    test('keeps library chants under "Explore more"', () {
      expect(_sections(ChantsFilter.all, yours: true, otherChants: true), [
        ChantsSection.yourSpacesHeading,
        ChantsSection.yourSpaceChantBooks,
        ChantsSection.exploreMoreHeading,
        ChantsSection.otherChants,
      ]);
    });

    test('is empty when there is nothing', () {
      expect(_sections(ChantsFilter.all), isEmpty);
    });
  });

  group('Chant books', () {
    test('lists books only, with no group headings', () {
      expect(
        _sections(
          ChantsFilter.chantBooks,
          my: true,
          yours: true,
          others: true,
          yourChants: true,
          otherChants: true,
        ),
        [
          ChantsSection.myChantBooks,
          ChantsSection.yourSpaceChantBooks,
          ChantsSection.otherSpaceChantBooks,
        ],
        reason: 'the rails carry the space titles themselves',
      );
    });
  });

  group('Single chants', () {
    test('lists the chants without books, grouped by space', () {
      expect(
        _sections(
          ChantsFilter.singleChants,
          my: true,
          yours: true,
          others: true,
          yourChants: true,
          otherChants: true,
        ),
        [
          ChantsSection.yourSpacesHeading,
          ChantsSection.yourChants,
          ChantsSection.exploreMoreHeading,
          ChantsSection.otherChants,
        ],
      );
      expect(_sections(ChantsFilter.singleChants, my: true), isEmpty);
    });

    test('no "From your spaces" group means no "Explore more" heading', () {
      expect(
        _sections(ChantsFilter.singleChants, yours: true, otherChants: true),
        [ChantsSection.otherChants],
      );
    });

    test('rows before See all: 3 under All, 4 under Single chants', () {
      expect(chantsRowLimit(ChantsFilter.all), 3);
      expect(chantsRowLimit(ChantsFilter.singleChants), 4);
    });
  });

  group('matchChantBooks', () {
    List<String> match(String query) =>
        matchChantBooks(
          const [
            ('Morning Prayers', 'My Sangha'),
            ('Evening Practice', null),
            ('Tara Practice', 'Dzongsar'),
          ],
          query,
          name: (b) => b.$1,
          subtitle: (b) => b.$2,
        ).map((b) => b.$1).toList();

    test('matches the name or the space, ignoring case', () {
      expect(match('practice'), ['Evening Practice', 'Tara Practice']);
      expect(match(' SANGHA '), ['Morning Prayers']);
      expect(match('dzong'), ['Tara Practice']);
    });

    test('matches nothing for a blank query or a miss', () {
      expect(match('  '), isEmpty);
      expect(match('medicine'), isEmpty);
    });
  });

  group('matchSpaceChants', () {
    const book = GroupRecitationCollection(id: 'b', groupId: 'g', name: 'B');
    SpaceChant chant(String title, String space) => SpaceChant(
      item: GroupRecitationCollectionItem(
        id: title,
        textId: title,
        title: title,
        language: 'en',
        type: '',
        displayOrder: 0,
      ),
      collection: book,
      spaceName: space,
    );

    test('matches title or space, your spaces first, split by audio', () {
      final chants = SpaceChants(
        yoursAudio: [chant('Tara praise', 'Mine')],
        yoursText: [chant('Refuge', 'Mine')],
        othersAudio: [chant('Medicine Buddha', 'Tara House')],
        othersText: [chant('Tara mantra', 'Other'), chant('Heart', 'Other')],
      );
      final found = matchSpaceChants(chants, 'tara');
      expect(found.audio.map((c) => c.item.title), [
        'Tara praise',
        'Medicine Buddha',
      ]);
      expect(found.text.map((c) => c.item.title), ['Tara mantra']);
    });
  });
}

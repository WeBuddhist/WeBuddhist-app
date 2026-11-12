import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_sections.dart';
import 'package:flutter_test/flutter_test.dart';

List<ChantsSection> _sections(
  ChantsFilter filter, {
  bool my = false,
  bool yours = false,
  bool others = false,
  bool text = false,
  bool yourAudio = false,
  bool otherAudio = false,
  bool yourText = false,
}) => chantsPageSections(
  filter: filter,
  hasMyChantBooks: my,
  hasYourSpaceChantBooks: yours,
  hasOtherSpaceChantBooks: others,
  hasTextOnlyChants: text,
  hasYourAudioChants: yourAudio,
  hasOtherAudioChants: otherAudio,
  hasYourTextChants: yourText,
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
          text: true,
        ),
        [
          ChantsSection.myChantBooks,
          ChantsSection.yourSpacesHeading,
          ChantsSection.yourSpaceChantBooks,
          ChantsSection.exploreMoreHeading,
          ChantsSection.otherSpaceChantBooks,
          ChantsSection.textOnlyChants,
        ],
      );
    });

    test('a new user gets the sections with no group headings', () {
      expect(_sections(ChantsFilter.all, others: true, text: true), [
        ChantsSection.otherSpaceChantBooks,
        ChantsSection.textOnlyChants,
      ]);
    });

    test('drops "Explore more" when nothing sits under it', () {
      expect(_sections(ChantsFilter.all, yours: true), [
        ChantsSection.yourSpacesHeading,
        ChantsSection.yourSpaceChantBooks,
      ]);
    });

    test('keeps library chants under "Explore more"', () {
      expect(_sections(ChantsFilter.all, yours: true, text: true), [
        ChantsSection.yourSpacesHeading,
        ChantsSection.yourSpaceChantBooks,
        ChantsSection.exploreMoreHeading,
        ChantsSection.textOnlyChants,
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
          text: true,
        ),
        [
          ChantsSection.myChantBooks,
          ChantsSection.yourSpaceChantBooks,
          ChantsSection.otherSpaceChantBooks,
        ],
        reason: 'the rails carry the space titles themselves',
      );
    });

    test('hides library chants', () {
      expect(_sections(ChantsFilter.chantBooks, yours: true, text: true), [
        ChantsSection.yourSpaceChantBooks,
      ]);
    });
  });

  group('Single chants', () {
    test('lists text-only chants alone', () {
      expect(
        _sections(
          ChantsFilter.singleChants,
          my: true,
          yours: true,
          others: true,
          text: true,
        ),
        [ChantsSection.textOnlyChants],
      );
      expect(_sections(ChantsFilter.singleChants, my: true), isEmpty);
    });
  });

  group('Chants with audio', () {
    test('All puts audio chants after each group\'s chant books', () {
      expect(
        _sections(
          ChantsFilter.all,
          yours: true,
          others: true,
          text: true,
          yourAudio: true,
          otherAudio: true,
        ),
        [
          ChantsSection.yourSpacesHeading,
          ChantsSection.yourSpaceChantBooks,
          ChantsSection.yourAudioChants,
          ChantsSection.exploreMoreHeading,
          ChantsSection.otherSpaceChantBooks,
          ChantsSection.otherAudioChants,
          ChantsSection.textOnlyChants,
        ],
      );
    });

    test('a new user gets audio chants with no headings', () {
      expect(
        _sections(ChantsFilter.all, others: true, text: true, otherAudio: true),
        [
          ChantsSection.otherSpaceChantBooks,
          ChantsSection.otherAudioChants,
          ChantsSection.textOnlyChants,
        ],
      );
    });

    test('Single chants groups audio and text chants without books', () {
      expect(
        _sections(
          ChantsFilter.singleChants,
          my: true,
          yours: true,
          others: true,
          text: true,
          yourAudio: true,
          otherAudio: true,
        ),
        [
          ChantsSection.yourSpacesHeading,
          ChantsSection.yourAudioChants,
          ChantsSection.exploreMoreHeading,
          ChantsSection.otherAudioChants,
          ChantsSection.textOnlyChants,
        ],
      );
    });

    test('no "From your spaces" group means no "Explore more" heading', () {
      expect(
        _sections(
          ChantsFilter.singleChants,
          yours: true,
          text: true,
          otherAudio: true,
        ),
        [ChantsSection.otherAudioChants, ChantsSection.textOnlyChants],
      );
    });

    test('the Chant books pill hides them', () {
      expect(_sections(ChantsFilter.chantBooks, yours: true, yourAudio: true), [
        ChantsSection.yourSpaceChantBooks,
      ]);
    });

    test('rows before See all: 3 under All, 4 under Single chants', () {
      expect(chantsRowLimit(ChantsFilter.all), 3);
      expect(chantsRowLimit(ChantsFilter.singleChants), 4);
    });
  });

  group('Text-only chants from your spaces', () {
    test('follow your audio chants, under All and Single chants', () {
      final expected = [
        ChantsSection.yourSpacesHeading,
        ChantsSection.yourAudioChants,
        ChantsSection.yourTextChants,
        ChantsSection.exploreMoreHeading,
        ChantsSection.textOnlyChants,
      ];
      expect(
        _sections(
          ChantsFilter.singleChants,
          yours: true,
          text: true,
          yourAudio: true,
          yourText: true,
        ),
        expected,
      );
      expect(
        _sections(
          ChantsFilter.all,
          yours: true,
          text: true,
          yourAudio: true,
          yourText: true,
        ),
        [
          ChantsSection.yourSpacesHeading,
          ChantsSection.yourSpaceChantBooks,
          ...expected.skip(1),
        ],
      );
    });

    test('are hidden under the Chant books pill', () {
      expect(_sections(ChantsFilter.chantBooks, yours: true, yourText: true), [
        ChantsSection.yourSpaceChantBooks,
      ]);
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

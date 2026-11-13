import 'package:flutter_pecha/features/practice/presentation/utils/chant_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chantArtworkUrl', () {
    test('prefers the recording, then the cover, then the space avatar', () {
      expect(
        chantArtworkUrl(
          audioImageUrl: 'audio',
          collectionImageUrl: 'cover',
          groupAvatarUrl: 'avatar',
        ),
        'audio',
      );
      expect(
        chantArtworkUrl(
          audioImageUrl: '  ',
          collectionImageUrl: 'cover',
          groupAvatarUrl: 'avatar',
        ),
        'cover',
      );
      expect(
        chantArtworkUrl(collectionImageUrl: '', groupAvatarUrl: ' avatar '),
        'avatar',
      );
    });

    test('is null when nothing is set', () {
      expect(chantArtworkUrl(), isNull);
      expect(chantArtworkUrl(audioImageUrl: ' ', groupAvatarUrl: ''), isNull);
    });
  });

  group('chantReciterLine', () {
    test('uses the reciter when sent, else the recording title', () {
      expect(
        chantReciterLine(reciterName: 'Dechen Angmo', audioTitle: 'x.mp3'),
        'Dechen Angmo',
      );
      expect(
        chantReciterLine(reciterName: ' ', audioTitle: ' Dzongsar '),
        'Dzongsar',
      );
      expect(chantReciterLine(), isNull);
    });

    test('drops an audio file ending from the recording title', () {
      expect(chantReciterLine(audioTitle: 'prayer.mp3'), 'prayer');
      expect(
        chantReciterLine(audioTitle: 'བསམ་པ་ལྷུན་གྲུབ།.M4A'),
        'བསམ་པ་ལྷུན་གྲུབ།',
      );
      expect(chantReciterLine(audioTitle: 'Dr. Smith'), 'Dr. Smith');
      expect(chantReciterLine(audioTitle: '.mp3'), isNull);
    });
  });

  group('chantPreview', () {
    test('returns short text as is, tags stripped and spaces collapsed', () {
      expect(
        chantPreview('<p>Namo tassa\n  bhagavato</p>'),
        'Namo tassa bhagavato',
      );
    });

    test('is null for missing or blank text', () {
      expect(chantPreview(null), isNull);
      expect(chantPreview('  <br/> '), isNull);
    });

    test('cuts long text at the last space and adds an ellipsis', () {
      final text = List.filled(40, 'namo').join(' '); // 199 chars
      final preview = chantPreview(text, maxChars: 22)!;
      expect(preview, 'namo namo namo namo…');
    });

    test('hard-cuts when no break keeps enough of the text', () {
      final preview = chantPreview('a ${'b' * 50}', maxChars: 10)!;
      expect(preview, 'a ${'b' * 8}…');
    });

    test('keeps a tsheg on the Tibetan syllable it ends', () {
      const tibetan = 'ན་མོ་གུ་རུ་བྷྱཿ་ན་མོ་བུདྡྷཱ་ཡ།';
      // Seven characters end mid-syllable at རུ; the tsheg before it wins.
      final preview = chantPreview(tibetan, maxChars: 7)!;
      expect(preview, 'ན་མོ་གུ་…');
    });

    test('never splits a Tibetan stack', () {
      // བྷྱཿ is one perceived character made of several code points.
      final preview = chantPreview('བྷྱཿ' * 20, maxChars: 5)!;
      expect(preview, '${'བྷྱཿ' * 5}…');
    });
  });
}

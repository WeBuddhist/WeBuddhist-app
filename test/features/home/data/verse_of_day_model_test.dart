import 'package:flutter_pecha/features/home/data/models/verse_of_day_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> payload({String? source}) => {
    'verse_of_day': {
      'id': 'v1',
      'verses': null,
      'verse': 'All phenomena arise from causes.',
      'image_url': 'https://example.com/a.webp',
      'ref_id': null,
      'source': source,
      'ref_type': null,
      'date': '2026-10-05',
      'group_info': [
        {'id': 'g1', 'title': 'Buddha'},
      ],
    },
  };

  test('parses source and group title and keeps them through a cache round trip', () {
    final model = VerseOfDayModel.fromJson(
      payload(source: 'Pratītyasamutpādahṛdaya'),
    );
    final cached = VerseOfDayModel.fromJson(model.toJson()).toEntity();

    expect(model.toEntity().source, 'Pratītyasamutpādahṛdaya');
    expect(model.toEntity().groupTitle, 'Buddha');
    expect(cached.source, 'Pratītyasamutpādahṛdaya');
    expect(cached.groupTitle, 'Buddha');
  });

  test('missing source yields an empty source', () {
    final entity = VerseOfDayModel.fromJson(payload()).toEntity();

    expect(entity.source, isEmpty);
    expect(entity.verse, 'All phenomena arise from causes.');
  });

  group('language fallback', () {
    Map<String, dynamic> untranslated() => {
      'verse_of_day': {
        'id': 'v2',
        'date': '2026-11-08',
        'verse': null,
        'verses': {'en': 'Hatred is never appeased by hatred.', 'bo': 'ཞེ་སྡང་།'},
        'source': null,
        'sources': {'en': 'Dhp 1.5', 'bo': 'ཆོས་ཀྱི་ཚིགས་སུ་བཅད་པ།'},
      },
    };

    test('reads verses[lang] when verse is null', () {
      final model = VerseOfDayModel.fromJson(untranslated(), language: 'bo');

      expect(model.verse, 'ཞེ་སྡང་།');
      expect(model.source, 'ཆོས་ཀྱི་ཚིགས་སུ་བཅད་པ།');
    });

    test('falls back to English when the language is missing', () {
      final model = VerseOfDayModel.fromJson(untranslated(), language: 'mn');

      expect(model.verse, 'Hatred is never appeased by hatred.');
      expect(model.source, 'Dhp 1.5');
    });

    test('keeps the resolved text through a cache round trip', () {
      final model = VerseOfDayModel.fromJson(untranslated(), language: 'bo');
      final cached = VerseOfDayModel.fromJson(model.toJson());

      expect(cached.verse, 'ཞེ་སྡང་།');
      expect(cached.source, 'ཆོས་ཀྱི་ཚིགས་སུ་བཅད་པ།');
    });
  });

  group('source inside the text', () {
    test('splits on the last ~ when there is no source', () {
      final model = VerseOfDayModel.fromJson({
        'id': 'v3',
        'verse': 'Mind ~ heart is the forerunner. ~ Dhammapada 1',
      });

      expect(model.verse, 'Mind ~ heart is the forerunner.');
      expect(model.source, 'Dhammapada 1');
    });

    test('leaves the text alone when a source is given', () {
      final model = VerseOfDayModel.fromJson({
        'id': 'v3',
        'verse': 'Mind is the forerunner ~ of all.',
        'source': 'Dhp 1',
      });

      expect(model.verse, 'Mind is the forerunner ~ of all.');
      expect(model.source, 'Dhp 1');
    });

    test('drops a leading ~ from a given source', () {
      final model = VerseOfDayModel.fromJson({
        'id': 'v5',
        'verse': 'Beings wander.',
        'source': '~Rāṣṭrapālaparipṛcchā sūtra',
      });

      expect(model.source, 'Rāṣṭrapālaparipṛcchā sūtra');
    });

    test('ignores a ~ with nothing after it', () {
      expect(splitVerseSource('Peace ~').verse, 'Peace ~');
      expect(splitVerseSource('Peace ~').source, isEmpty);
    });
  });

  group('tryParse', () {
    test('is null for a day with no verse', () {
      expect(VerseOfDayModel.tryParse({'verse_of_day': null}), isNull);
      expect(VerseOfDayModel.tryParse(null), isNull);
      expect(
        VerseOfDayModel.tryParse({
          'verse_of_day': {'id': 'v4', 'verse': null, 'verses': null},
        }),
        isNull,
      );
    });

    test('parses a verse', () {
      expect(VerseOfDayModel.tryParse(payload())?.id, 'v1');
    });
  });

  test('cache entry keeps a missing day and its fetch time', () {
    final entry = VerseOfDayCacheEntry(fetchedAt: DateTime.utc(2026, 11, 8, 6));
    final restored = VerseOfDayCacheEntry.fromJson(entry.toJson());

    expect(restored.verse, isNull);
    expect(restored.fetchedAt, DateTime.utc(2026, 11, 8, 6));
    expect(restored.isFreshAt(DateTime.utc(2026, 11, 9, 4)), isTrue);
    expect(restored.isFreshAt(DateTime.utc(2026, 11, 9, 5)), isFalse);
  });
}

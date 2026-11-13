import 'package:flutter_pecha/features/group_profile/data/models/group_practice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses chant recordings and drops ones without a url', () {
    final model = GroupRecitationCollectionModel.fromJson({
      'id': 'collection-1',
      'group_id': 'group-1',
      'name': 'Morning',
      'items': [
        {
          'id': 'chant-1',
          'text_id': 'text-1',
          'title': 'Aspiration',
          'language': 'en',
          'type': null,
          'display_order': 1,
          'audio': [
            {
              'id': 'audio-1',
              'title': 'prayer.mp3',
              'asset_url': 'https://cdn/prayer.mp3',
            },
            {'id': 'audio-blank', 'title': 'missing.mp3', 'asset_url': '  '},
            {
              'id': 'audio-2',
              'file_name': 'fallback.mp3',
              'asset_url': 'https://cdn/fallback.mp3',
            },
          ],
        },
        {
          'id': 'chant-2',
          'text_id': 'text-2',
          'title': 'No audio',
          'display_order': 2,
        },
      ],
    });

    final collection = model.toEntity();
    final first = collection.items.singleWhere((item) => item.id == 'chant-1');
    expect(first.audio.map((audio) => audio.title), [
      'prayer.mp3',
      'fallback.mp3',
    ]);
    expect(first.audio.first.assetUrl, 'https://cdn/prayer.mp3');
    expect(
      collection.items.singleWhere((item) => item.id == 'chant-2').audio,
      isEmpty,
    );
    // No audio_item_count in a detail response: counted from the items.
    expect(collection.audioItemCount, 1);
    expect(collection.hasAudio, isTrue);
  });

  test('reads reciter_name and image_url, blank ones as absent', () {
    final model = GroupRecitationCollectionModel.fromJson({
      'id': 'c',
      'group_id': 'g',
      'name': 'Evening',
      'items': [
        {
          'id': 'chant-1',
          'text_id': 'text-1',
          'audio': [
            {
              'id': 'a-1',
              'title': 'Refuge',
              'asset_url': 'https://cdn/a.mp3',
              'reciter_name': 'Dechen Angmo',
              'image_url': 'https://cdn/a.webp',
            },
            {
              'id': 'a-2',
              'title': 'Refuge 2',
              'asset_url': 'https://cdn/b.mp3',
              'reciter_name': ' ',
            },
          ],
        },
      ],
    });

    final audio = model.toEntity().items.single.audio;
    expect(audio.first.reciterName, 'Dechen Angmo');
    expect(audio.first.imageUrl, 'https://cdn/a.webp');
    expect(audio.last.reciterName, isNull);
    expect(audio.last.imageUrl, isNull);
  });

  test('a list row uses audio_item_count, else reads as no audio', () {
    final withCount = GroupRecitationCollectionModel.fromJson({
      'id': 'c',
      'group_id': 'g',
      'name': 'Evening',
      'item_count': 9,
      'audio_item_count': 3,
    });
    expect(withCount.toEntity().audioItemCount, 3);

    final withoutCount = GroupRecitationCollectionModel.fromJson({
      'id': 'c',
      'group_id': 'g',
      'name': 'Evening',
      'item_count': 9,
    });
    expect(withoutCount.toEntity().hasAudio, isFalse);
  });
}

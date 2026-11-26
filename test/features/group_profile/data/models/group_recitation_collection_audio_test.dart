import 'package:flutter_pecha/features/group_profile/data/models/group_practice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chant items carry no audio: recordings come from the library', () {
    final model = GroupRecitationCollectionModel.fromJson({
      'id': 'collection-1',
      'group_id': 'group-1',
      'name': 'Morning',
      'items': [
        {
          'id': 'chant-1',
          'text_id': 'text-1',
          'title': 'Aspiration',
          'display_order': 1,
          'audio': [
            {'id': 'audio-1', 'asset_url': 'https://cdn/prayer.mp3'},
          ],
        },
      ],
    });

    final collection = model.toEntity();
    expect(collection.items.single.textId, 'text-1');
    // Studio audio no longer counts toward the book's audio badge.
    expect(collection.audioItemCount, 0);
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

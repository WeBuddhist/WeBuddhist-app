import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MyRecitationCollectionItemModel', () {
    test('preserves fractional display_order values', () {
      final item = MyRecitationCollectionItemModel.fromJson({
        'id': 'item-1',
        'text_id': 'text-1',
        'title': 'Morning chant',
        'display_order': 1.4,
      });

      expect(item.displayOrder, 1.4);
    });

    test('parses playable recordings sorted by display_order', () {
      final item = MyRecitationCollectionItemModel.fromJson({
        'id': 'item-1',
        'text_id': 'text-1',
        'audio': [
          {
            'id': 'a-2',
            'title': ' Second ',
            'url': 'https://cdn/2.mp3',
            'duration_ms': 61000,
            'display_order': 2,
          },
          {'id': 'a-blank', 'title': 'Blank', 'url': '  ', 'display_order': 0},
          {'id': 'a-null', 'title': 'No url', 'url': null},
          {
            'id': 'a-1',
            'title': 'First',
            'url': 'https://cdn/1.mp3',
            'display_order': 1,
            'reciter_name': 'Dechen Angmo',
            'image_url': 'https://cdn/1.webp',
          },
          'not a map',
        ],
      });

      expect(item.hasAudio, isTrue);
      expect(item.audio.map((a) => a.id), ['a-1', 'a-2']);
      expect(item.audio.first.reciterName, 'Dechen Angmo');
      expect(item.audio.first.imageUrl, 'https://cdn/1.webp');
      expect(item.audio.last.title, 'Second');
      expect(item.audio.last.durationMs, 61000);
      expect(item.audio.last.reciterName, isNull);
    });

    test('has no audio when the field is missing or not a list', () {
      for (final raw in [null, 'x', <Object>[]]) {
        final item = MyRecitationCollectionItemModel.fromJson({
          'id': 'item-1',
          'text_id': 'text-1',
          'audio': raw,
        });
        expect(item.audio, isEmpty);
        expect(item.hasAudio, isFalse);
      }
    });

    test('treats a blank reciter_name or image_url as absent', () {
      final audio = MyRecitationCollectionItemAudioModel.fromJson({
        'id': 'a',
        'url': 'https://cdn/a.mp3',
        'reciter_name': '  ',
        'image_url': '',
      });
      expect(audio.reciterName, isNull);
      expect(audio.imageUrl, isNull);
      expect(audio.title, '');
    });
  });

  group('MyRecitationCollectionModel', () {
    test('reads audio_item_count when the backend sends it', () {
      final model = MyRecitationCollectionModel.fromJson({
        'id': 'c-1',
        'name': 'Morning',
        'item_count': 6,
        'audio_item_count': 2,
      });
      expect(model.audioItemCount, 2);
      expect(model.hasAudio, isTrue);
    });

    test('names the source owner of an import, else the owner', () {
      final imported = MyRecitationCollectionModel.fromJson({
        'id': 'c-1',
        'name': 'Evening',
        'reference': {
          'owner': {'name': ' Tuesday Group '},
        },
        'owner': {'name': 'Someone else'},
      });
      expect(imported.ownerName, 'Tuesday Group');
      expect(imported.isImported, isTrue);

      final public = MyRecitationCollectionModel.fromJson({
        'id': 'c-2',
        'name': 'Morning',
        'owner': {'name': 'Dechen'},
      });
      expect(public.ownerName, 'Dechen');
      expect(public.isImported, isFalse);

      final own = MyRecitationCollectionModel.fromJson({
        'id': 'c-3',
        'name': 'Mine',
        'owner': {'name': '  '},
      });
      expect(own.ownerName, isNull);
    });

    test('defaults to no audio while the field is absent', () {
      final model = MyRecitationCollectionModel.fromJson({
        'id': 'c-1',
        'name': 'Morning',
        'item_count': 6,
      });
      expect(model.audioItemCount, 0);
      expect(model.hasAudio, isFalse);
    });
  });

  group('MyRecitationCollectionDetailModel', () {
    test('keeps each item audio through the detail response', () {
      final detail = MyRecitationCollectionDetailModel.fromJson({
        'id': 'c-1',
        'name': 'Morning',
        'items': [
          {
            'id': 'i-1',
            'text_id': 't-1',
            'display_order': 1,
            'audio': [
              {'id': 'a', 'title': 'A', 'url': 'https://cdn/a.mp3'},
            ],
          },
        ],
      });
      expect(detail.items.single.audio.single.url, 'https://cdn/a.mp3');
    });

    test('an imported collection is marked, with its source owner', () {
      final imported = MyRecitationCollectionDetailModel.fromJson({
        'id': 'c-2',
        'name': 'Evening',
        'reference': {
          'id': 'src',
          'source_type': 'GROUP',
          'owner': {'id': 'u', 'name': ' Tenzin '},
        },
      });
      expect(imported.isImported, isTrue);
      expect(imported.ownerName, 'Tenzin');

      final own = MyRecitationCollectionDetailModel.fromJson({
        'id': 'c-3',
        'name': 'Mine',
        'reference': null,
      });
      expect(own.isImported, isFalse);
      expect(own.ownerName, isNull);
    });
  });

  group('UpdateMyRecitationCollectionItemDisplayOrderRequest', () {
    test('serializes display_order for the PATCH endpoint', () {
      const request = UpdateMyRecitationCollectionItemDisplayOrderRequest(
        displayOrder: 2.5,
      );

      expect(request.toJson(), {'display_order': 2.5});
    });
  });
}

import 'package:flutter_pecha/features/home/data/models/today_event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses group avatar and keeps it through a cache round trip', () {
    final model = TodayEventModel.fromJson({
      'id': 'e1',
      'metadata': {'id': 'm1', 'name': 'Act of kindness', 'language': 'EN'},
      'start_date': '2026-10-13T00:30:00Z',
      'end_date': '2026-10-17T18:29:00Z',
      'timezone': 'Asia/Kolkata',
      'start_time': '06:00',
      'end_time': '23:59',
      'group_avatar_url': 'https://example.com/avatar.webp',
    });

    expect(model.groupAvatarUrl, 'https://example.com/avatar.webp');
    final cached = TodayEventModel.fromJson(model.toJson()).toEntity();
    expect(cached.groupAvatarUrl, 'https://example.com/avatar.webp');
    expect(cached.name, 'Act of kindness');
  });

  test('response keeps every event in order', () {
    final response = TodayEventsResponseModel.fromJson({
      'events': [
        {
          'id': 'e1',
          'metadata': {'name': 'First'},
        },
        {
          'id': 'e2',
          'metadata': {'name': 'Second'},
        },
      ],
      'total': 2,
    });

    expect(response.events.map((e) => e.id), ['e1', 'e2']);
    expect(response.events.first.groupAvatarUrl, isNull);
  });

  group('metadata as a list of translations', () {
    Map<String, dynamic> event(List<Map<String, dynamic>> metadata) => {
      'id': 'e1',
      'metadata': metadata,
      'start_date': '2026-11-11T00:30:00Z',
      'end_date': '2026-11-14T18:29:00Z',
      'timezone': 'Asia/Kolkata',
      'start_time': '06:00',
      'end_time': '23:59',
    };

    test('response with list metadata parses instead of failing', () {
      final response = TodayEventsResponseModel.fromJson({
        'events': [
          event([
            {'id': 'm1', 'name': 'Act of kindness', 'language': 'EN'},
          ]),
        ],
      });

      expect(
        response.toEntities(language: 'en').single.name,
        'Act of kindness',
      );
    });

    test('picks the content language when it has a name', () {
      final model = TodayEventModel.fromJson(
        event([
          {'name': 'Tara puja', 'language': 'EN'},
          {'name': 'སྒྲོལ་མ།', 'description': 'བོད་ཡིག', 'language': 'BO'},
        ]),
      );

      final entity = model.toEntity(language: 'bo');
      expect(entity.name, 'སྒྲོལ་མ།');
      expect(entity.description, 'བོད་ཡིག');
      expect(model.toEntity(language: 'en').name, 'Tara puja');
    });

    test('a Tibetan-only event keeps its name in English', () {
      final model = TodayEventModel.fromJson(
        event([
          {'name': 'ཚོད་ལྟ།', 'language': 'BO'},
        ]),
      );

      expect(model.toEntity(language: 'en').name, 'ཚོད་ལྟ།');
    });

    test('falls back to English before other languages', () {
      final model = TodayEventModel.fromJson(
        event([
          {'name': '度母', 'language': 'ZH'},
          {'name': '', 'language': 'BO'},
          {'name': 'Tara puja', 'language': 'EN'},
        ]),
      );

      expect(model.toEntity(language: 'bo').name, 'Tara puja');
    });

    test('list metadata survives a cache round trip', () {
      final model = TodayEventModel.fromJson(
        event([
          {'name': 'Tara puja', 'language': 'EN'},
          {'name': 'སྒྲོལ་མ།', 'language': 'BO'},
        ]),
      );

      final cached = TodayEventModel.fromJson(model.toJson());
      expect(cached.toEntity(language: 'bo').name, 'སྒྲོལ་མ།');
      expect(cached.toEntity(language: 'en').name, 'Tara puja');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_prayer_request_source_dto.dart';
import 'package:flutter_pecha/features/group_chat/presentation/screens/my_prayer_requests_screen.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/prayer_request_tile.dart';
import 'package:flutter_test/flutter_test.dart';

/// A row of `GET /chat/prayer-requests/me`, as the backend sends it.
Map<String, dynamic> _myRequestJson({
  Map<String, dynamic>? group,
  Map<String, dynamic>? event,
}) {
  return {
    'id': 'm1',
    'room_id': 'r1',
    'room_kind': event == null ? 'GROUP' : 'EVENT',
    'body': 'May all be well',
    'created_at': '2026-09-11T10:04:00+00:00',
    'prayer_count': 3,
    'total_prayer_count': 6,
    'recent_prayers': const [],
    if (group != null) 'group': group,
    if (event != null) 'event': event,
  };
}

const _space = {
  'id': 'g1',
  'slug': 'dzongsar-shedra',
  'name': 'Dzongsar Shedra',
  'avatar_url': 'https://cdn/g1.png',
};

const _event = {
  'id': 'e1',
  'name': '100,000 mani mantra',
  'image': {
    'thumbnail': 'https://cdn/e1-t.png',
    'medium': 'https://cdn/e1-m.png',
    'original': 'https://cdn/e1-o.png',
  },
};

void main() {
  group('ChatMessageDTO prayer request source', () {
    test('reads the space and event of an event request', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space, event: _event),
      );

      expect(request.group?.id, 'g1');
      expect(request.group?.slug, 'dzongsar-shedra');
      expect(request.group?.avatarUrl, 'https://cdn/g1.png');
      expect(request.event?.id, 'e1');
      expect(request.event?.name, '100,000 mani mantra');
      expect(request.event?.thumbnailUrl, 'https://cdn/e1-t.png');
    });

    test('a space request has no event', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space),
      );

      expect(request.group?.name, 'Dzongsar Shedra');
      expect(request.event, isNull);
    });

    test('survives the screen cache round trip', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space, event: _event),
      );

      final restored = ChatMessageDTO.fromJson(request.toJson());

      expect(restored, request);
      expect(restored.group, request.group);
      expect(restored.event, request.event);
    });

    test('copyWith keeps the source', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space, event: _event),
      );

      final edited = request.copyWith(body: 'Edited', isCompleted: true);

      expect(edited.group, request.group);
      expect(edited.event, request.event);
    });

    test('a room message without a source writes none', () {
      final json =
          ChatMessageDTO.fromMyPrayerRequestJson(_myRequestJson()).toJson();

      expect(json.containsKey('group'), isFalse);
      expect(json.containsKey('event'), isFalse);
    });

    test('an event image falls back to its larger sizes', () {
      const event = PrayerRequestEventDTO(id: 'e1', imageMedium: 'm.png');
      expect(event.thumbnailUrl, 'm.png');
      expect(const PrayerRequestEventDTO(id: 'e1').thumbnailUrl, isNull);
    });
  });

  group('prayerRequestSourceLabel', () {
    test('names the space and the event for an event request', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space, event: _event),
      );
      expect(
        prayerRequestSourceLabel(request),
        'Dzongsar Shedra · 100,000 mani mantra',
      );
    });

    test('names only the space for a space request', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space),
      );
      expect(prayerRequestSourceLabel(request), 'Dzongsar Shedra');
    });

    test('is null when the space was deleted and there is no event', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(_myRequestJson());
      expect(prayerRequestSourceLabel(request), isNull);
    });
  });

  group('myPrayerRequestSourcePath', () {
    test('opens the event on its prayer list', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space, event: _event),
      );
      expect(myPrayerRequestSourcePath(request), '/home/events/e1?prayers=1');
    });

    test('opens the space on its prayer list', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(
        _myRequestJson(group: _space),
      );
      expect(myPrayerRequestSourcePath(request), '/home/group/g1?prayers=1');
    });

    test('is null without a source', () {
      final request = ChatMessageDTO.fromMyPrayerRequestJson(_myRequestJson());
      expect(myPrayerRequestSourcePath(request), isNull);
    });
  });

  group('PrayerRequestTile source row', () {
    Future<void> pump(
      WidgetTester tester,
      ChatMessageDTO request, {
      VoidCallback? onOpenSource,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PrayerRequestTile(
              request: request,
              displayName: 'Tenzin',
              isOwn: true,
              onOpenSource: onOpenSource,
            ),
          ),
        ),
      );
    }

    final source = find.byKey(const ValueKey('prayer-request-source'));

    testWidgets('shows the event source and opens it on tap', (tester) async {
      var opened = 0;
      await pump(
        tester,
        ChatMessageDTO.fromMyPrayerRequestJson(
          _myRequestJson(group: _space, event: _event),
        ),
        onOpenSource: () => opened++,
      );

      expect(source, findsOneWidget);
      expect(
        find.text('Dzongsar Shedra · 100,000 mani mantra'),
        findsOneWidget,
      );

      await tester.tap(source);
      expect(opened, 1);
    });

    testWidgets('shows only the space for a space request', (tester) async {
      await pump(
        tester,
        ChatMessageDTO.fromMyPrayerRequestJson(_myRequestJson(group: _space)),
        onOpenSource: () {},
      );

      expect(find.text('Dzongsar Shedra'), findsOneWidget);
    });

    testWidgets('is hidden without onOpenSource', (tester) async {
      await pump(
        tester,
        ChatMessageDTO.fromMyPrayerRequestJson(
          _myRequestJson(group: _space, event: _event),
        ),
      );

      expect(source, findsNothing);
    });

    testWidgets('is hidden when there is nothing to name', (tester) async {
      await pump(
        tester,
        ChatMessageDTO.fromMyPrayerRequestJson(_myRequestJson()),
        onOpenSource: () {},
      );

      expect(source, findsNothing);
    });
  });
}

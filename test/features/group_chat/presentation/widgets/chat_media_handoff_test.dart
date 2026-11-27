import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_local_media_cache.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_viewer.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_message_media_bubble.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_pending_media_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessageMedia _photo(String id, {int? width, int? height}) {
  return ChatMessageMedia(
    id: id,
    mediaType: 'IMAGE',
    quality: 'STANDARD',
    mimeType: 'image/jpeg',
    fileSizeBytes: 1,
    width: width,
    height: height,
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

ChatPendingMedia _pending(
  List<File> files, {
  String caption = '',
  double? aspect,
}) {
  return ChatPendingMedia(
    files: files,
    mediaType: 'IMAGE',
    caption: caption,
    parent: null,
    current: 0,
    total: files.length,
    singleAspectRatio: aspect,
  );
}

void main() {
  tearDown(ChatLocalMediaCache.instance.clear);

  group('ChatLocalMediaCache', () {
    test('keeps files by media id and drops the oldest past its cap', () {
      final cache = ChatLocalMediaCache.instance;
      cache.registerAll({
        for (var i = 0; i < 205; i++)
          'm$i': ChatLocalMediaFiles(image: File('/tmp/$i.jpg')),
      });

      expect(cache['m0'], isNull);
      expect(cache['m4'], isNull);
      expect(cache['m5']?.image.path, '/tmp/5.jpg');
      expect(cache['m204']?.image.path, '/tmp/204.jpg');
    });

    test('ignores an empty id', () {
      ChatLocalMediaCache.instance.register(
        '',
        ChatLocalMediaFiles(image: File('/tmp/x.jpg')),
      );
      expect(ChatLocalMediaCache.instance[''], isNull);
    });
  });

  group('pending to sent hand-off', () {
    final files = [File('/tmp/a.jpg'), File('/tmp/b.jpg'), File('/tmp/c.jpg')];

    /// The pending widget draws its own 240 bubble, 4px padding; the sent
    /// grid is measured inside the same 232 its message bubble gives it.
    Future<Size> gridSize(WidgetTester tester, Widget bubble) async {
      final sized =
          bubble is ChatMessageMediaBubble
              ? SizedBox(width: 232, child: bubble)
              : bubble;
      await tester.pumpWidget(_host(sized));
      return tester.getSize(find.byType(ChatMediaGrid));
    }

    testWidgets('three photos keep their shape when the upload finishes', (
      tester,
    ) async {
      final pending = await gridSize(
        tester,
        ChatPendingMediaBubble(
          pending: _pending(files),
          onCancel: () {},
          onRetry: () {},
        ),
      );
      final sent = await gridSize(
        tester,
        ChatMessageMediaBubble(
          media: [_photo('1'), _photo('2'), _photo('3')],
          isDark: false,
        ),
      );
      expect(sent, pending);
    });

    testWidgets('a lone photo is drawn at its own ratio in both states', (
      tester,
    ) async {
      final pending = await gridSize(
        tester,
        ChatPendingMediaBubble(
          pending: _pending([files.first], aspect: 3 / 4),
          onCancel: () {},
          onRetry: () {},
        ),
      );
      final sent = await gridSize(
        tester,
        ChatMessageMediaBubble(
          media: [_photo('1', width: 900, height: 1200)],
          isDark: false,
        ),
      );
      expect(pending.width / pending.height, closeTo(3 / 4, 0.01));
      expect(sent, pending);
    });

    testWidgets('a sent photo paints from the file this device sent', (
      tester,
    ) async {
      ChatLocalMediaCache.instance.register(
        '1',
        ChatLocalMediaFiles(image: files.first),
      );
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 232,
            child: ChatMessageMediaBubble(
              media: [_photo('1')],
              isDark: false,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      final inner = (image.image as ResizeImage).imageProvider;
      expect((inner as FileImage).file.path, files.first.path);
    });

    testWidgets('the pending caption hugs the right edge', (tester) async {
      await tester.pumpWidget(
        _host(
          ChatPendingMediaBubble(
            pending: _pending([files.first], caption: 'Hi'),
            onCancel: () {},
            onRetry: () {},
          ),
        ),
      );

      final grid = tester.getRect(find.byType(ChatMediaGrid));
      final caption = tester.getRect(find.text('Hi'));
      expect(grid.right - caption.right, closeTo(8, 0.5));
    });
  });

  group('ChatMediaViewer', () {
    testWidgets('a swipe down closes it; a short one springs back', (
      tester,
    ) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      unawaited(
        ChatMediaViewer.show(
          hostContext,
          media: [_photo('1')],
          senderName: 'Tenzin',
          sentAt: DateTime(2026, 11, 27, 9),
          messageId: 'msg',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatMediaViewer), findsOneWidget);

      await tester.timedDrag(
        find.byType(PageView),
        const Offset(0, 60),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatMediaViewer), findsOneWidget);

      await tester.timedDrag(
        find.byType(PageView),
        const Offset(0, 260),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatMediaViewer), findsNothing);
    });

    testWidgets('the caption sits against the right edge, 16px under the photo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          ChatMediaViewer(
            media: [_photo('1', width: 1200, height: 900)],
            senderName: 'Tenzin',
            sentAt: DateTime(2026, 11, 27, 9),
            caption: 'Morning prayers',
          ),
        ),
      );

      final page = tester.getRect(find.byType(PageView));
      // A 4:3 photo across 390 is 292.5 tall, centred in the page.
      final photoBottom = page.top + (page.height + 390 * 3 / 4) / 2;
      final caption = tester.getRect(find.text('Morning prayers'));
      final text = tester.widget<Text>(find.text('Morning prayers'));
      expect(text.textAlign, TextAlign.end);
      expect(390 - caption.right, closeTo(16, 0.5));
      expect(caption.top - photoBottom, closeTo(16, 0.5));
    });

    testWidgets('tapping a photo hides and shows the header', (tester) async {
      await tester.pumpWidget(
        _host(
          ChatMediaViewer(
            media: [_photo('1')],
            senderName: 'Tenzin',
            sentAt: DateTime(2026, 11, 27, 9),
          ),
        ),
      );
      double headerOpacity() =>
          tester
              .widget<AnimatedOpacity>(
                find
                    .ancestor(
                      of: find.text('Tenzin'),
                      matching: find.byType(AnimatedOpacity),
                    )
                    .first,
              )
              .opacity;

      expect(headerOpacity(), 1);
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      // Past the double-tap window.
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(headerOpacity(), 0);
    });
  });
}

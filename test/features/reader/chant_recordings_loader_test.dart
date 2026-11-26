import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_recitation_audio_sheet.dart';
import 'package:flutter_pecha/features/library/data/models/library_recording.dart';
import 'package:flutter_pecha/features/reader/presentation/utils/chant_recordings_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../library/library_test_server.dart';

void main() {
  group('ChantRecordingsLoader', () {
    test('a load that works is ready with its recordings', () async {
      final loader = ChantRecordingsLoader(
        () async => const [LibraryRecording(id: 'rec-1')],
      );
      addTearDown(loader.dispose);
      final seen = <ChantRecordingsStatus>[];
      loader.addListener(() => seen.add(loader.status));

      expect(loader.status, ChantRecordingsStatus.idle);
      expect(await loader.fetch(), isTrue);

      expect(seen, [
        ChantRecordingsStatus.loading,
        ChantRecordingsStatus.ready,
      ]);
      expect(loader.recordings.single.id, 'rec-1');
      expect(loader.hasFailed, isFalse);
    });

    test('a chant with no recordings is ready, not failed', () async {
      final loader = ChantRecordingsLoader(() async => const []);
      addTearDown(loader.dispose);

      expect(await loader.fetch(), isTrue);
      expect(loader.status, ChantRecordingsStatus.ready);
      expect(loader.recordings, isEmpty);
    });

    test('a failed load says so and a retry asks again', () async {
      var calls = 0;
      final loader = ChantRecordingsLoader(() async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return const [LibraryRecording(id: 'rec-1')];
      });
      addTearDown(loader.dispose);

      await expectLater(loader.fetch(), throwsException);
      expect(loader.hasFailed, isTrue);
      expect(loader.recordings, isEmpty);

      expect(await loader.fetch(), isTrue);
      expect(calls, 2);
      expect(loader.hasFailed, isFalse);
      expect(loader.recordings.single.id, 'rec-1');
    });

    test('a second fetch while one runs is ignored', () async {
      final gate = Completer<List<LibraryRecording>>();
      var calls = 0;
      final loader = ChantRecordingsLoader(() {
        calls++;
        return gate.future;
      });
      addTearDown(loader.dispose);

      final first = loader.fetch();
      expect(loader.isLoading, isTrue);
      expect(await loader.fetch(), isFalse);
      gate.complete(const []);
      expect(await first, isTrue);
      expect(calls, 1);
    });

    test('a load that lands after leaving is dropped quietly', () async {
      final gate = Completer<List<LibraryRecording>>();
      final loader = ChantRecordingsLoader(() => gate.future);
      var notified = 0;
      final pending = loader.fetch();
      loader.addListener(() => notified++);

      loader.dispose();
      gate.completeError(Exception('offline'));

      expect(await pending, isFalse);
      expect(notified, 0);
      expect(await loader.fetch(), isFalse);
    });

    test('leaving while it loads keeps the list but plays nothing', () async {
      final gate = Completer<List<LibraryRecording>>();
      final loader = ChantRecordingsLoader(() => gate.future);
      addTearDown(loader.dispose);

      final pending = loader.fetch();
      // The pop starts: the reader is still mounted during its animation.
      loader.cancelPending();
      gate.complete(const [LibraryRecording(id: 'rec-1')]);

      expect(await pending, isFalse);
      expect(loader.status, ChantRecordingsStatus.ready);
      expect(loader.recordings.single.id, 'rec-1');
    });

    test('a failure that lands after leaving is not reported', () async {
      final gate = Completer<List<LibraryRecording>>();
      final loader = ChantRecordingsLoader(() => gate.future);
      addTearDown(loader.dispose);

      final pending = loader.fetch();
      loader.cancelPending();
      gate.completeError(Exception('offline'));

      expect(await pending, isFalse);
      expect(loader.hasFailed, isTrue);
    });

    test('a fetch started after a cancel acts as usual', () async {
      var fail = false;
      final loader = ChantRecordingsLoader(() async {
        if (fail) throw Exception('offline');
        return const [LibraryRecording(id: 'rec-1')];
      });
      addTearDown(loader.dispose);

      loader.cancelPending();
      expect(await loader.fetch(), isTrue);

      fail = true;
      await expectLater(loader.fetch(), throwsException);
    });

    test('a retry reaches the library again after a failure', () async {
      var fail = true;
      final server = LibraryTestServer({
        '/v2/editions/ed-1':
            (_) => jsonBody({'id': 'ed-1', 'text_id': 'text-1'}),
        '/v2/editions/ed-1/recordings':
            (_) =>
                fail
                    ? jsonBody({'detail': 'down'}, statusCode: 503)
                    : jsonBody([
                      {
                        'id': 'rec-1',
                        'title': {'en': 'Voice only'},
                      },
                    ]),
        '/v2/texts/text-1':
            (_) => jsonBody({
              'id': 'text-1',
              'title': {'bo': 'x'},
              'language': 'bo',
              'audios': const [],
            }),
      });
      final repo = server.repository();
      final loader = ChantRecordingsLoader(
        () => repo.getChantRecordings('ed-1'),
      );
      addTearDown(loader.dispose);

      await expectLater(loader.fetch(), throwsA(anything));
      expect(loader.hasFailed, isTrue);

      fail = false;
      expect(await loader.fetch(), isTrue);
      expect(loader.recordings.single.id, 'rec-1');
      expect(server.count('/v2/editions/ed-1/recordings'), 2);
    });
  });

  group('ChantAudioRetryButton', () {
    Future<void> pump(WidgetTester tester, Widget child) {
      return tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    testWidgets('offers a retry and reports the tap', (tester) async {
      var taps = 0;
      await pump(tester, ChantAudioRetryButton(onPressed: () => taps++));

      expect(find.byIcon(AppAssets.arrowCounterClockwise), findsOneWidget);
      expect(find.bySemanticsLabel('Retry'), findsOneWidget);

      await tester.tap(find.byType(ChantAudioRetryButton));
      expect(taps, 1);
    });

    testWidgets('shows a spinner and ignores taps while retrying', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        ChantAudioRetryButton(onPressed: () => taps++, isLoading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(AppAssets.arrowCounterClockwise), findsNothing);

      await tester.tap(find.byType(ChantAudioRetryButton));
      expect(taps, 0);
    });
  });
}

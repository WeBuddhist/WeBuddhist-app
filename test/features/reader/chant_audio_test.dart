import 'package:flutter_pecha/features/library/data/models/library_recording.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_segment_audio_controller.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_pecha/features/reader/presentation/screens/reader_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../library/library_test_server.dart';
import '../plans/fake_audio_player.dart';

void main() {
  group('playsChantRecordings', () {
    test('chant readers load library recordings', () {
      for (final source in [
        NavigationSource.recitationList,
        NavigationSource.routine,
        NavigationSource.groupRecitationCollection,
        NavigationSource.myRecitationCollection,
      ]) {
        expect(
          NavigationContext(source: source).playsChantRecordings,
          isTrue,
          reason: '$source',
        );
      }
    });

    test('plans, the library reader and group accumulations do not', () {
      for (final source in [
        NavigationSource.plan,
        NavigationSource.normal,
        NavigationSource.search,
        NavigationSource.deepLink,
        NavigationSource.groupAccumulatorChant,
      ]) {
        expect(
          NavigationContext(source: source).playsChantRecordings,
          isFalse,
          reason: '$source',
        );
      }
    });

    test('a plan step on a chant text keeps the plan\'s own audio', () {
      final context = NavigationContext(
        source: NavigationSource.plan,
        planTextItems: [
          PlanTextItem.sourceReference(
            textId: 'chant-edition',
            title: 'Tara',
            subtaskId: 's1',
            audioUrl: 'https://cdn/step.mp3',
          ),
        ],
        currentTextIndex: 0,
        dayAudioUrl: 'https://cdn/day.mp3',
      );
      expect(context.playsChantRecordings, isFalse);
      expect(context.currentAudioUrl, 'https://cdn/step.mp3');
    });
  });

  group('ChantAudioTrack', () {
    const recordings = [
      LibraryRecording(
        id: 'rec-1',
        title: {'en': 'Voice only', 'bo': 'གསུང་ཁོ་ན།'},
      ),
      LibraryRecording(id: 'rec-2', title: {'en': 'With music'}),
    ];

    test('fromRecordings keeps the order and picks the UI language', () {
      final tracks = ChantAudioTrack.fromRecordings(recordings, 'bo');
      expect(tracks.map((t) => t.id), ['rec-1', 'rec-2']);
      expect(tracks.map((t) => t.title), ['གསུང་ཁོ་ན།', 'With music']);
      expect(ChantAudioTrack.fromRecordings(const [], 'en'), isEmpty);
    });

    test('toPlay keeps the pick while offered, else the first', () {
      final tracks = ChantAudioTrack.fromRecordings(recordings, 'en');
      expect(ChantAudioTrack.toPlay(const [], tracks.last), isNull);
      expect(ChantAudioTrack.toPlay(tracks, null), tracks.first);
      expect(ChantAudioTrack.toPlay(tracks, tracks.last), tracks.last);
      expect(
        ChantAudioTrack.toPlay(
          tracks,
          const ChantAudioTrack(id: 'gone', title: 'Old'),
        ),
        tracks.first,
      );
    });
  });

  group('chantRecordingAudioController', () {
    setUp(() {
      PlanSegmentAudioController.preferredSpeed = 1.0;
      PlanSegmentAudioController.preferredRepeat = false;
    });

    test('plays the library link and asks again after it expires', () async {
      var served = 0;
      final server = LibraryTestServer({
        '/v2/recordings/rec-1/audio-url':
            (_) => jsonBody({
              'url': 'https://s3/rec-1?sig=${++served}',
              'expires_in': 3600,
            }),
      });
      final player = FakeAudioPlayer();
      final controller = chantRecordingAudioController(
        server.repository(),
        const ChantAudioTrack(id: 'rec-1', title: 'Voice only'),
        createPlayer: () => player,
      );
      addTearDown(controller.dispose);

      expect(controller.hasAudio, isTrue);
      expect(server.requests, isEmpty);

      await controller.maybeAutoPlay();
      expect(player.urls, ['https://s3/rec-1?sig=1']);

      player.advanceTo(const Duration(minutes: 1, seconds: 5));
      player.fail();
      await pumpEventQueue();

      expect(server.count('/v2/recordings/rec-1/audio-url'), 2);
      expect(player.urls.last, 'https://s3/rec-1?sig=2');
      expect(player.seeks.last, const Duration(minutes: 1, seconds: 5));
      expect(controller.buttonState, PlanAudioButtonState.pause);
    });

    test('a recording with no link stays ready to retry', () async {
      final server = LibraryTestServer({
        '/v2/recordings/rec-1/audio-url':
            (_) => jsonBody({'url': '', 'expires_in': 0}),
      });
      final player = FakeAudioPlayer();
      final controller = chantRecordingAudioController(
        server.repository(),
        const ChantAudioTrack(id: 'rec-1', title: 'Voice only'),
        createPlayer: () => player,
      );
      addTearDown(controller.dispose);

      await controller.maybeAutoPlay();

      expect(player.urls, isEmpty);
      expect(controller.buttonState, PlanAudioButtonState.play);
    });
  });
}

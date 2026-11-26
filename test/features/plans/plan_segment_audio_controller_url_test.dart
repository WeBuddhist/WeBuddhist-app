import 'dart:async';

import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_segment_audio_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_audio_player.dart';

void main() {
  setUp(() {
    PlanSegmentAudioController.preferredSpeed = 1.0;
    PlanSegmentAudioController.preferredRepeat = false;
  });

  /// A chant recording: each [resolveUrl] call hands out the next link.
  ({
    PlanSegmentAudioController controller,
    FakeAudioPlayer player,
    List<int> asks,
  })
  chant({
    Duration refreshCooldown = const Duration(seconds: 10),
    Future<String> Function(int ask)? resolve,
    FakeAudioPlayer? player,
  }) {
    final fake = player ?? FakeAudioPlayer();
    final asks = <int>[];
    final controller = PlanSegmentAudioController(
      url: null,
      startMs: 0,
      endMs: null,
      onSegmentComplete: () {},
      refreshCooldown: refreshCooldown,
      createPlayer: () => fake,
      resolveUrl: () {
        asks.add(asks.length + 1);
        return resolve?.call(asks.length) ??
            Future.value('https://s3/rec?sig=${asks.length}');
      },
    );
    addTearDown(controller.dispose);
    return (controller: controller, player: fake, asks: asks);
  }

  group('a chant recording without a fixed url', () {
    test('counts as audio and fetches its link on first play', () async {
      final (:controller, :player, :asks) = chant();
      expect(controller.hasAudio, isTrue);
      expect(controller.url, isNull);
      expect(asks, isEmpty);

      await controller.maybeAutoPlay();

      expect(asks, [1]);
      expect(player.urls, ['https://s3/rec?sig=1']);
      expect(player.seeks, [Duration.zero]);
      expect(player.playCalls, 1);
      expect(controller.buttonState, PlanAudioButtonState.pause);
    });

    test('pause and play keep the same link', () async {
      final (:controller, :player, :asks) = chant();
      await controller.maybeAutoPlay();

      await controller.toggle();
      expect(controller.buttonState, PlanAudioButtonState.play);
      await controller.toggle();

      expect(asks, [1]);
      expect(player.urls, hasLength(1));
      expect(player.playCalls, 2);
      expect(controller.buttonState, PlanAudioButtonState.pause);
    });

    test('an expired link mid-file is replaced and resumes in place', () async {
      final (:controller, :player, :asks) = chant();
      await controller.maybeAutoPlay();

      player.advanceTo(const Duration(seconds: 42));
      player.fail();
      await pumpEventQueue();

      expect(asks, [1, 2]);
      expect(player.urls.last, 'https://s3/rec?sig=2');
      expect(player.seeks.last, const Duration(seconds: 42));
      expect(player.playCalls, 2);
      expect(controller.buttonState, PlanAudioButtonState.pause);
    });

    test(
      'a second error soon after stops; play then fetches and resumes',
      () async {
        final (:controller, :player, :asks) = chant();
        await controller.maybeAutoPlay();
        player.advanceTo(const Duration(seconds: 10));
        player.fail();
        await pumpEventQueue();
        expect(asks, [1, 2]);

        // The fresh link fails too, within the cooldown: no loop of refreshes.
        player.advanceTo(const Duration(seconds: 12));
        player.fail();
        await pumpEventQueue();
        expect(asks, [1, 2]);
        expect(controller.buttonState, PlanAudioButtonState.play);

        await controller.toggle();
        expect(asks, [1, 2, 3]);
        expect(player.seeks.last, const Duration(seconds: 12));
        expect(controller.buttonState, PlanAudioButtonState.pause);
      },
    );

    test('an error while paused waits for play to fetch a new link', () async {
      final (:controller, :player, :asks) = chant();
      await controller.maybeAutoPlay();
      player.advanceTo(const Duration(seconds: 30));
      await controller.toggle(); // pause

      player.fail();
      await pumpEventQueue();
      expect(asks, [1]);
      expect(controller.url, isNull);
      expect(controller.buttonState, PlanAudioButtonState.play);

      await controller.toggle();
      expect(asks, [1, 2]);
      expect(player.seeks.last, const Duration(seconds: 30));
      expect(controller.buttonState, PlanAudioButtonState.pause);
    });

    test(
      'a link that fails to load is retried once with a fresh one',
      () async {
        final player = FakeAudioPlayer(failUrl: (url) => url.endsWith('sig=1'));
        final (:controller, player: _, :asks) = chant(player: player);

        await controller.maybeAutoPlay();

        expect(asks, [1, 2]);
        expect(player.urls, ['https://s3/rec?sig=1', 'https://s3/rec?sig=2']);
        expect(player.playCalls, 1);
        expect(controller.buttonState, PlanAudioButtonState.pause);
      },
    );

    test('a file that never loads gives up after one retry', () async {
      final player = FakeAudioPlayer(failUrl: (_) => true);
      final (:controller, player: _, :asks) = chant(player: player);

      await controller.maybeAutoPlay();

      expect(asks, [1, 2]);
      expect(player.playCalls, 0);
      expect(controller.buttonState, PlanAudioButtonState.play);
    });

    test('a failed link request leaves play ready to try again', () async {
      var fail = true;
      final (:controller, :player, :asks) = chant(
        resolve: (ask) async {
          if (fail) throw Exception('offline');
          return 'https://s3/rec?sig=$ask';
        },
      );

      await controller.maybeAutoPlay();
      expect(asks, [1]);
      expect(player.urls, isEmpty);
      expect(controller.buttonState, PlanAudioButtonState.play);

      fail = false;
      await controller.toggle();
      expect(player.urls, ['https://s3/rec?sig=2']);
      expect(controller.buttonState, PlanAudioButtonState.pause);
    });

    test('leaving while the link loads plays nothing', () async {
      final gate = Completer<String>();
      final (:controller, :player, asks: _) = chant(
        resolve: (_) => gate.future,
      );

      final starting = controller.maybeAutoPlay();
      await pumpEventQueue();
      controller.cancel();
      gate.complete('https://s3/rec?sig=1');
      await starting;

      expect(player.urls, isEmpty);
      expect(player.playCalls, 0);
    });
  });

  group('a plan task with a fixed url', () {
    PlanSegmentAudioController plan(FakeAudioPlayer player) {
      final controller = PlanSegmentAudioController(
        url: 'https://cdn/day.mp3',
        startMs: 5000,
        endMs: null,
        onSegmentComplete: () {},
        createPlayer: () => player,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    test('plays its url and ignores player errors as before', () async {
      final player = FakeAudioPlayer();
      final controller = plan(player);

      await controller.maybeAutoPlay();
      player.fail();
      await pumpEventQueue();

      expect(player.urls, ['https://cdn/day.mp3']);
      expect(player.seeks, [const Duration(seconds: 5)]);
      expect(controller.url, 'https://cdn/day.mp3');
    });

    test('a load failure is not retried', () async {
      final player = FakeAudioPlayer(failUrl: (_) => true);
      final controller = plan(player);

      await controller.maybeAutoPlay();

      expect(player.urls, ['https://cdn/day.mp3']);
      expect(controller.buttonState, PlanAudioButtonState.play);
    });
  });
}

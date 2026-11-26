import 'dart:async';

import 'package:flutter_pecha/features/timer/presentation/services/ambient_sound_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  group('AmbientSoundPlayer', () {
    test('play returns once playback starts, not when it ends', () async {
      final audio = _FakeAudioPlayer();
      final player = AmbientSoundPlayer(createPlayer: () => audio);

      // The fake's play() never completes on its own, like a looping track.
      await player.play('https://example.test/rain.mp3');

      expect(audio.playCalls, 1);
    });

    test('a pause issued while the track loads keeps it silent', () async {
      final audio = _FakeAudioPlayer(holdLoading: true);
      final player = AmbientSoundPlayer(createPlayer: () => audio);

      final playing = player.play('https://example.test/rain.mp3');
      await pumpEventQueue();
      await player.pause();
      audio.finishLoading();
      await playing;

      expect(audio.playCalls, 0);

      await player.resume();
      expect(audio.playCalls, 1);
    });

    test('stop clears a pending pause for the next track', () async {
      final audio = _FakeAudioPlayer();
      final player = AmbientSoundPlayer(createPlayer: () => audio);

      await player.pause();
      await player.stop();
      await player.play('https://example.test/rain.mp3');

      expect(audio.playCalls, 1);
    });
  });
}

/// Stands in for just_audio's player, which needs a platform channel. Only the
/// calls [AmbientSoundPlayer] makes are implemented.
class _FakeAudioPlayer implements AudioPlayer {
  _FakeAudioPlayer({bool holdLoading = false})
    : _loading = holdLoading ? Completer<void>() : null;

  final Completer<void>? _loading;
  int playCalls = 0;

  void finishLoading() => _loading?.complete();

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    await _loading?.future;
    return null;
  }

  @override
  Future<void> play() {
    playCalls++;
    return Completer<void>().future;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

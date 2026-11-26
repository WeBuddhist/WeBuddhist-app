import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:just_audio/just_audio.dart';

/// Loops a single ambient sound track — used both for the previews in the
/// "Ambient sounds" picker sheet and for the track of a running session.
/// One track plays at a time: starting a new one stops whatever was playing.
///
/// Volume is local-only UI state for the preview in the picker sheet; it is
/// never sent to the backend (the create-timer API has no volume field).
class AmbientSoundPlayer {
  AmbientSoundPlayer({@visibleForTesting AudioPlayer Function()? createPlayer})
    : _createPlayer = createPlayer ?? AudioPlayer.new,
      _logger = AppLogger('AmbientSoundPlayer');

  final AudioPlayer Function() _createPlayer;
  final AppLogger _logger;
  AudioPlayer? _player;
  bool _disposed = false;

  /// Whether the caller wants sound held. Kept here rather than read off the
  /// player, because [pause] can arrive while [play] is still loading a track:
  /// there is no player playing yet to pause, and the track must not start
  /// once it has loaded. Cleared only by [resume] and [stop].
  bool _paused = false;

  /// Bumped by every [play]/[stop] request. Tapping through the picker starts
  /// overlapping requests whose awaits can complete out of order, so a request
  /// only installs its player while it is still the most recent one.
  int _requestId = 0;

  Future<void> play(String url, {double volume = 1}) async {
    if (_disposed || url.isEmpty) return;
    final requestId = ++_requestId;
    await _stopCurrent();
    if (_disposed || requestId != _requestId) return;

    final player = _createPlayer();
    _player = player;
    try {
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.setUrl(url);
      if (_disposed || requestId != _requestId || _player != player) {
        if (_player == player) _player = null;
        await player.dispose();
        return;
      }
      if (_paused) return;
      _startPlayback(player);
    } catch (e) {
      _logger.warning('Failed to play ambient sound: $e');
    }
  }

  /// Starts [player] without waiting on it. just_audio's `play()` completes
  /// only when playback is paused or stopped, which for a looping track is
  /// never on its own, so awaiting it would hold the caller for the whole
  /// session.
  void _startPlayback(AudioPlayer player) {
    unawaited(
      player.play().catchError((Object e) {
        _logger.warning('Failed to play ambient sound: $e');
      }),
    );
  }

  Future<void> pause() async {
    _paused = true;
    try {
      await _player?.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    _paused = false;
    final player = _player;
    if (player == null) return;
    _startPlayback(player);
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player?.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> stop() async {
    _requestId++;
    _paused = false;
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}

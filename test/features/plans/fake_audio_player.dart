import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Stands in for just_audio's player, which needs a platform channel. Only
/// the calls [PlanSegmentAudioController] makes are implemented.
class FakeAudioPlayer implements AudioPlayer {
  FakeAudioPlayer({this.failUrl});

  final bool Function(String url)? failUrl;
  final List<String> urls = [];
  final List<Duration?> seeks = [];
  int playCalls = 0;

  final _state = StreamController<PlayerState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration?>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  Duration _position = Duration.zero;
  ProcessingState _processing = ProcessingState.idle;
  bool _playing = false;

  void advanceTo(Duration position) {
    _position = position;
    _positions.add(position);
  }

  /// What just_audio does when the file stops loading mid-play.
  void fail() {
    _processing = ProcessingState.idle;
    _playing = false;
    _events.addError(Exception('403 link expired'));
  }

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    urls.add(url);
    if (failUrl?.call(url) ?? false) {
      _processing = ProcessingState.idle;
      throw Exception('403 link expired');
    }
    _processing = ProcessingState.ready;
    return const Duration(minutes: 3);
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks.add(position);
    _position = position ?? Duration.zero;
  }

  @override
  Future<void> play() {
    playCalls++;
    _playing = true;
    return Completer<void>().future;
  }

  @override
  Future<void> pause() async => _playing = false;

  @override
  Future<void> stop() async {
    _playing = false;
    _processing = ProcessingState.idle;
  }

  @override
  Future<void> dispose() async {}

  @override
  Stream<PlayerState> get playerStateStream => _state.stream;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<Duration?> get durationStream => _durations.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _events.stream;

  @override
  Duration get position => _position;

  @override
  ProcessingState get processingState => _processing;

  @override
  bool get playing => _playing;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

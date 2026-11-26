import 'dart:collection';

import 'package:flutter_pecha/core/utils/app_logger.dart';

final _logger = AppLogger('ForegroundGate');

/// Holds analytics calls back until the app has been shown to a person.
///
/// audio_service (media buttons, media resumption) and iOS background launches
/// run main() with no screen. Calls made then wait here and go out in order
/// when the UI first opens; if it never does, they die with the process.
class ForegroundGate {
  ForegroundGate({this.maxPending = 200});

  /// Oldest calls are dropped past this, so a long headless run stays bounded.
  final int maxPending;

  final Queue<Future<void> Function()> _pending = Queue();
  bool _isOpen = false;
  bool _isOpening = false;

  bool get isOpen => _isOpen;

  int get pendingCount => _pending.length;

  /// Runs [call] now once open, otherwise queues it.
  Future<void> run(Future<void> Function() call) {
    if (_isOpen) return call();
    if (_pending.length >= maxPending) _pending.removeFirst();
    _pending.add(call);
    return Future.value();
  }

  /// Forgets queued calls, e.g. when the identity they belong to is reset.
  void discardPending() => _pending.clear();

  /// Sends queued calls in order, then lets later calls straight through.
  ///
  /// Calls arriving while the queue drains join its end, so order holds.
  Future<void> open() async {
    if (_isOpen || _isOpening) return;
    _isOpening = true;
    try {
      while (_pending.isNotEmpty) {
        final call = _pending.removeFirst();
        try {
          await call();
        } catch (e) {
          _logger.warning('Queued analytics call failed: $e');
        }
      }
      _isOpen = true;
    } finally {
      _isOpening = false;
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

/// One recitation shown as counted but held back for [window], so Undo can
/// drop it before it reaches the counters. The counters only go up, so an
/// Undo cannot take a count back once made.
class DeferredRecitation {
  DeferredRecitation({required this.window, required this.onCommit});

  /// How long Undo is offered.
  final Duration window;

  /// Counts the held recitation. Called once per [hold] that is not undone.
  final VoidCallback onCommit;

  Timer? _timer;

  /// True while a recitation is held.
  bool get isPending => _timer != null;

  /// Holds one recitation, counting one already held first.
  void hold() {
    commit();
    _timer = Timer(window, commit);
  }

  /// Drops the held recitation. False when none was held, e.g. the window
  /// had already closed and it was counted.
  bool undo() {
    final timer = _timer;
    if (timer == null) return false;
    timer.cancel();
    _timer = null;
    return true;
  }

  /// Counts the held recitation now, if there is one.
  void commit() {
    final timer = _timer;
    if (timer == null) return;
    timer.cancel();
    _timer = null;
    onCommit();
  }
}

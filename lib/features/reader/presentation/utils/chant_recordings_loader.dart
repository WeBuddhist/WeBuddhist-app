import 'package:flutter/foundation.dart';
import 'package:flutter_pecha/features/library/data/models/library_recording.dart';

enum ChantRecordingsStatus { idle, loading, ready, failed }

/// Loads the library recordings of the chant on screen and remembers how
/// that went, so a failed request is shown as one (with a retry) instead of
/// reading as a chant with no recordings.
class ChantRecordingsLoader extends ChangeNotifier {
  ChantRecordingsLoader(this._load);

  final Future<List<LibraryRecording>> Function() _load;

  ChantRecordingsStatus _status = ChantRecordingsStatus.idle;
  ChantRecordingsStatus get status => _status;

  List<LibraryRecording> _recordings = const [];

  /// The last list that loaded; kept while a retry is in flight.
  List<LibraryRecording> get recordings => _recordings;

  bool get isLoading => _status == ChantRecordingsStatus.loading;
  bool get hasFailed => _status == ChantRecordingsStatus.failed;

  bool _disposed = false;

  /// Bumped by [cancelPending]; a fetch that started under an older value
  /// still stores its result but reports that it should not be acted on.
  int _generation = 0;

  /// The reader is leaving (or moving to another text): a load still in
  /// flight lands, but its [fetch] returns false and does not throw, so the
  /// caller starts no audio and reports no error.
  void cancelPending() => _generation++;

  /// Loads the list. Returns true when it loaded (possibly empty), false
  /// when it was already loading, this was disposed meanwhile, or
  /// [cancelPending] ran while it loaded. A failed request sets [hasFailed]
  /// and rethrows so the caller can report it, unless it was cancelled. The
  /// repository drops failed lookups, so calling again asks again.
  Future<bool> fetch() async {
    if (_disposed || isLoading) return false;
    final generation = _generation;
    _set(ChantRecordingsStatus.loading);
    try {
      final recordings = await _load();
      if (_disposed) return false;
      _recordings = recordings;
      _set(ChantRecordingsStatus.ready);
      return generation == _generation;
    } catch (_) {
      if (_disposed) return false;
      _set(ChantRecordingsStatus.failed);
      if (generation != _generation) return false;
      rethrow;
    }
  }

  void _set(ChantRecordingsStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

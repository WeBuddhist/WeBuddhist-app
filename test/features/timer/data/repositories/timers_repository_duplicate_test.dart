import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/timer/data/datasource/timers_local_datasource.dart';
import 'package:flutter_pecha/features/timer/data/datasource/timers_remote_datasource.dart';
import 'package:flutter_pecha/features/timer/data/models/preset_timer_model.dart';
import 'package:flutter_pecha/features/timer/data/repositories/timers_repository.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocal implements TimersLocalDatasource {
  _FakeLocal(this.cached);

  final List<PresetTimerModel>? cached;

  @override
  Future<String?> currentUserId() async => 'user-1';

  @override
  List<PresetTimerModel>? readPresetTimers(
    String userId, {
    required int skip,
    required int limit,
  }) => cached;

  @override
  Future<void> upsertPresetTimer(
    String userId, {
    required PresetTimerModel timer,
    required int skip,
    required int limit,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote implements TimersRemoteDatasource {
  int creates = 0;
  int updates = 0;

  @override
  Future<PresetTimerModel> createUserTimer({
    required String name,
    required String description,
    required int durationMs,
    String? ambientSoundId,
    required bool bellAtStart,
    required bool bellAtEnd,
  }) async {
    creates++;
    return PresetTimerModel(
      id: 'new',
      name: name,
      description: description,
      durationMs: durationMs,
      ambientSoundId: ambientSoundId,
      type: kPresetTimerTypeUserCreated,
    );
  }

  @override
  Future<PresetTimerModel> updateUserTimer({
    required String timerId,
    required String name,
    required String description,
    required int durationMs,
    required String? ambientSoundId,
  }) async {
    updates++;
    return PresetTimerModel(
      id: timerId,
      name: name,
      description: description,
      durationMs: durationMs,
      ambientSoundId: ambientSoundId,
      type: kPresetTimerTypeUserCreated,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PresetTimerModel _userTimer(
  String id, {
  int durationMs = 1200000,
  String? sound,
  String? title,
}) => PresetTimerModel(
  id: id,
  name: '20 minutes',
  description: title,
  durationMs: durationMs,
  ambientSoundId: sound,
  type: kPresetTimerTypeUserCreated,
);

bool _isDuplicateFailure(Object? failure) =>
    failure is ValidationFailure && failure.code == 'timer_duplicate_setup';

void main() {
  group('TimersRepository duplicate check', () {
    test('create is blocked when duration, sound, and title match', () async {
      final remote = _FakeRemote();
      final repo = TimersRepository(
        remote: remote,
        local: _FakeLocal([_userTimer('a', sound: 'rain')]),
      );

      final result = await repo.createUserTimer(
        name: '20 minutes',
        description: '',
        durationMs: 1200000,
        ambientSoundId: 'rain',
      );

      expect(_isDuplicateFailure(result.getLeft().toNullable()), isTrue);
      expect(remote.creates, 0);
    });

    test('create is allowed when only the title differs', () async {
      final remote = _FakeRemote();
      final repo = TimersRepository(
        remote: remote,
        local: _FakeLocal([_userTimer('a', title: 'Morning')]),
      );

      final result = await repo.createUserTimer(
        name: '20 minutes',
        description: 'Evening',
        durationMs: 1200000,
      );

      expect(result.isRight(), isTrue);
      expect(remote.creates, 1);
    });

    test('presets never count as duplicates', () async {
      final remote = _FakeRemote();
      final repo = TimersRepository(
        remote: remote,
        local: _FakeLocal([
          const PresetTimerModel(
            id: 'p',
            name: '20 minutes',
            durationMs: 1200000,
          ),
        ]),
      );

      final result = await repo.createUserTimer(
        name: '20 minutes',
        description: '',
        durationMs: 1200000,
      );

      expect(result.isRight(), isTrue);
    });

    test('an older duplicate can still be saved without changes', () async {
      // Two identical timers saved before the duplicate rule existed.
      final remote = _FakeRemote();
      final repo = TimersRepository(
        remote: remote,
        local: _FakeLocal([_userTimer('a'), _userTimer('b')]),
      );

      final result = await repo.updateUserTimer(
        timerId: 'a',
        name: '20 minutes',
        description: '',
        durationMs: 1200000,
        ambientSoundId: null,
      );

      expect(result.isRight(), isTrue);
      expect(remote.updates, 1);
    });

    test('an older duplicate can be renamed apart', () async {
      final remote = _FakeRemote();
      final repo = TimersRepository(
        remote: remote,
        local: _FakeLocal([_userTimer('a'), _userTimer('b')]),
      );

      final result = await repo.updateUserTimer(
        timerId: 'a',
        name: '20 minutes',
        description: 'Morning',
        durationMs: 1200000,
        ambientSoundId: null,
      );

      expect(result.isRight(), isTrue);
    });

    test('an edit into another timer\'s setup is blocked', () async {
      final remote = _FakeRemote();
      final repo = TimersRepository(
        remote: remote,
        local: _FakeLocal([
          _userTimer('a', durationMs: 600000),
          _userTimer('b'),
        ]),
      );

      final result = await repo.updateUserTimer(
        timerId: 'a',
        name: '20 minutes',
        description: '',
        durationMs: 1200000,
        ambientSoundId: null,
      );

      expect(_isDuplicateFailure(result.getLeft().toNullable()), isTrue);
      expect(remote.updates, 0);
    });

    test('with no cached list the save goes through', () async {
      final remote = _FakeRemote();
      final repo = TimersRepository(remote: remote, local: _FakeLocal(null));

      final result = await repo.createUserTimer(
        name: '20 minutes',
        description: '',
        durationMs: 1200000,
      );

      expect(result.isRight(), isTrue);
    });
  });
}

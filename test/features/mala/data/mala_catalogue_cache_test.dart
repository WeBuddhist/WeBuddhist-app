import 'dart:convert';
import 'dart:io';

import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_local_datasource.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_remote_datasource.dart';
import 'package:flutter_pecha/features/mala/data/models/accumulator_model.dart';
import 'package:flutter_pecha/features/mala/data/repositories/mala_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Remote that is either offline or returns a fixed catalogue.
class _FakeRemote implements MalaRemoteDataSource {
  _FakeRemote({this.presets});

  List<PresetAccumulatorModel>? presets;
  int fetches = 0;

  @override
  Future<List<PresetAccumulatorModel>> fetchPresets({
    String? language,
    String? search,
  }) async {
    fetches++;
    final result = presets;
    if (result == null) throw const NetworkException('offline');
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _preset(
  String id, {
  Map<String, dynamic>? deityImage,
  String? lastUsedAt,
}) => {
  'id': id,
  if (lastUsedAt != null) 'last_used_at': lastUsedAt,
  'target_count': 108,
  'metadata': [
    {'language': 'EN', 'name': 'Preset $id'},
  ],
  'mantra': {
    'id': 'mantra-$id',
    'mantra': 'om',
    'pronunciation': 'Om',
    if (deityImage != null) 'deity_image': deityImage,
  },
};

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('mala_catalogue_cache');
    Hive.init(tempDir.path);
    await MalaLocalDataSource.init();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(MalaLocalDataSource.boxName);
    await Hive.deleteBoxFromDisk(MalaLocalDataSource.groupBoxName);
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Box<String> box() => Hive.box<String>(MalaLocalDataSource.boxName);

  test(
    'offline with only a pre-v3 cache serves it instead of failing',
    () async {
      await box().put('catalogue:en', jsonEncode([_preset('old')]));
      final repo = MalaRepositoryImpl(
        remote: _FakeRemote(),
        local: MalaLocalDataSource(),
      );

      final result = await repo.getCatalogue(language: 'en', userId: 'u1');

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => []).single.presetId, 'old');
    },
  );

  test('offline with no cache at all still fails', () async {
    final repo = MalaRepositoryImpl(
      remote: _FakeRemote(),
      local: MalaLocalDataSource(),
    );

    final result = await repo.getCatalogue(language: 'en', userId: 'u1');

    expect(result.isLeft(), isTrue);
  });

  test('an online load writes v3 and deletes the older caches', () async {
    await box().put('catalogue:en', jsonEncode([_preset('old')]));
    await box().put('catalogue:v2:en', jsonEncode([_preset('old')]));
    final fresh = PresetAccumulatorModel.fromJson(
      _preset('new', deityImage: {'medium': 'https://example.com/m.webp'}),
    );
    final repo = MalaRepositoryImpl(
      remote: _FakeRemote(presets: [fresh]),
      local: MalaLocalDataSource(),
    );

    // A pre-v3 cache is not served while online, so this hits the remote.
    final result = await repo.getCatalogue(language: 'en', userId: 'u1');

    final mantras = result.getOrElse((_) => []);
    expect(mantras.single.presetId, 'new');
    expect(mantras.single.deityImage?.medium, 'https://example.com/m.webp');
    expect(box().get('catalogue:en'), isNull);
    expect(box().get('catalogue:v2:en'), isNull);
    expect(box().get('catalogue:v3:u1:en'), isNotNull);
  });

  test('one account never reads another\'s cached usage', () async {
    final remote = _FakeRemote(
      presets: [
        PresetAccumulatorModel.fromJson(
          _preset('a', lastUsedAt: '2026-11-18T07:42:10+00:00'),
        ),
      ],
    );
    final repo = MalaRepositoryImpl(
      remote: remote,
      local: MalaLocalDataSource(),
    );
    await repo.getCatalogue(language: 'en', userId: 'u1');

    expect(MalaLocalDataSource().readCatalogue('u2', 'en'), isNull);
    remote.presets = null;
    final other = await repo.getCatalogue(language: 'en', userId: 'u2');
    expect(other.isLeft(), isTrue, reason: 'offline, and u1\'s is not u2\'s');
  });

  test('a legacy cache is served without usage times', () async {
    await box().put(
      'catalogue:v2:en',
      jsonEncode([_preset('old', lastUsedAt: '2026-11-18T07:42:10+00:00')]),
    );
    final repo = MalaRepositoryImpl(
      remote: _FakeRemote(),
      local: MalaLocalDataSource(),
    );

    final result = await repo.getCatalogue(language: 'en', userId: 'u1');

    final mantra = result.getOrElse((_) => []).single;
    expect(mantra.presetId, 'old');
    expect(mantra.lastUsedAt, isNull);
  });

  test('without an account or with a search, nothing is cached', () async {
    final repo = MalaRepositoryImpl(
      remote: _FakeRemote(
        presets: [PresetAccumulatorModel.fromJson(_preset('a'))],
      ),
      local: MalaLocalDataSource(),
    );
    await repo.getCatalogue(language: 'en');
    await repo.getCatalogue(language: 'en', userId: 'u1', search: 'tara');
    expect(box().keys.where((k) => '$k'.startsWith('catalogue')), isEmpty);
  });

  test(
    'refresh stores fresh usage, joins a running one, never throws',
    () async {
      final remote = _FakeRemote(
        presets: [
          PresetAccumulatorModel.fromJson(
            _preset('a', lastUsedAt: '2026-11-20T07:00:00+00:00'),
          ),
        ],
      );
      final repo = MalaRepositoryImpl(
        remote: remote,
        local: MalaLocalDataSource(),
      );

      await Future.wait([
        repo.refreshCatalogue(userId: 'u1', language: 'en'),
        repo.refreshCatalogue(userId: 'u1', language: 'en'),
      ]);
      expect(remote.fetches, 1);
      expect(
        MalaLocalDataSource().readCatalogue('u1', 'en')!.single.lastUsedAt,
        DateTime.utc(2026, 11, 20, 7),
      );

      remote.presets = null;
      await repo.refreshCatalogue(userId: 'u1', language: 'en');
      expect(remote.fetches, 2, reason: 'a finished refresh is not reused');
      expect(MalaLocalDataSource().readCatalogue('u1', 'en'), isNotNull);
    },
  );

  test('a first load and a refresh at once download it once', () async {
    final remote = _FakeRemote(
      presets: [PresetAccumulatorModel.fromJson(_preset('a'))],
    );
    final repo = MalaRepositoryImpl(
      remote: remote,
      local: MalaLocalDataSource(),
    );

    final (load, _) =
        await (
          repo.getCatalogue(language: 'en', userId: 'u1'),
          repo.refreshCatalogue(userId: 'u1', language: 'en'),
        ).wait;

    expect(remote.fetches, 1);
    expect(load.getOrElse((_) => []).single.presetId, 'a');
  });

  test('a shared first load still reports being offline', () async {
    final remote = _FakeRemote();
    final repo = MalaRepositoryImpl(
      remote: remote,
      local: MalaLocalDataSource(),
    );

    // The refresh starts first; the load joins it.
    final (_, load) =
        await (
          repo.refreshCatalogue(userId: 'u1', language: 'en'),
          repo.getCatalogue(language: 'en', userId: 'u1'),
        ).wait;

    expect(remote.fetches, 1);
    expect(load.isLeft(), isTrue, reason: 'only the refresh hides errors');
  });

  test(
    'clearing on logout drops every catalogue but keeps the counts',
    () async {
      final local = MalaLocalDataSource();
      final presets = [PresetAccumulatorModel.fromJson(_preset('a'))];
      await local.writeCatalogue('u1', 'en', presets);
      await local.writeCatalogue('u2', 'bo', presets);
      await box().put('catalogue:v2:en', jsonEncode([_preset('old')]));
      await box().put('catalogue:en', jsonEncode([_preset('older')]));
      await local.recordTap('u1', 'a');

      await local.clearCatalogues();

      expect(local.readCatalogue('u1', 'en', allowLegacy: true), isNull);
      expect(local.readCatalogue('u2', 'bo', allowLegacy: true), isNull);
      expect(box().keys.where((k) => '$k'.startsWith('catalogue:')), isEmpty);
      expect(
        local.read('u1', 'a').isDirty,
        isTrue,
        reason: 'unsynced tap kept',
      );
    },
  );
}

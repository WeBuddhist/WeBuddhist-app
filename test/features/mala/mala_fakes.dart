import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_remote_datasource.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_image_option.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra_appearance.dart';
import 'package:flutter_pecha/features/mala/domain/repositories/mala_appearance_repository.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_sync_manager.dart';
import 'package:flutter_pecha/features/mala/presentation/services/mala_sound_player.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fakes for the collaborators every mala counter provider pulls in, so a test
/// can run the real notifiers without the network, audio or sync timers.

/// Storage that only knows the signed-in user's id.
class FakeUserStorage extends Fake implements LocalStorageService {
  FakeUserStorage(this.userId);

  final String userId;

  @override
  Future<T?> get<T>(String key) async =>
      key == StorageKeys.currentUserId ? userId as T : null;
}

class FakeMalaRemote extends Fake implements MalaRemoteDataSource {
  @override
  Future<List<int>> fetchImageBytes(String url) async => const [];
}

/// Accepts taps and flushes without syncing anything.
class FakeMalaSync extends Fake implements MalaSyncManager {
  @override
  void Function(String groupAccumulatorId)? onGroupCountSynced;

  @override
  void Function(String presetId)? onPersonalCountSynced;

  @override
  void onTap({required bool roundComplete}) {}

  @override
  Future<void> flush(SyncReason reason) async {}
}

class SilentMalaSoundPlayer extends Fake implements MalaSoundPlayer {
  @override
  void play() {}
}

/// In-memory appearance server: remembers PATCHes and can be made to fail.
/// Like the real one, it resolves `deity_image` and `mala_skin_url` to the
/// pick, else to the option or skin marked default.
class FakeMalaAppearanceRepository implements MalaAppearanceRepository {
  FakeMalaAppearanceRepository({
    this.deityOptions = const [],
    this.skinList = const [],
    this.deityImageId,
    this.malaSkinId,
  });

  final List<MalaImageOption> deityOptions;
  final List<MalaSkin> skinList;
  String? deityImageId;
  String? malaSkinId;

  /// When true, every PATCH throws and changes nothing.
  bool failSaves = false;

  /// Each PATCH body, as sent.
  final List<Map<String, String?>> patches = [];

  MantraAppearance _current(String mantraId) {
    String? skinUrl;
    for (final skin in skinList) {
      if (malaSkinId == null ? skin.isDefault : skin.id == malaSkinId) {
        skinUrl = skin.url;
      }
    }
    ResponsiveImage? deity;
    for (final option in deityOptions) {
      if (deityImageId == null ? option.isDefault : option.id == deityImageId) {
        deity = option.image;
      }
    }
    return MantraAppearance(
      mantraId: mantraId,
      deityImageId: deityImageId,
      malaSkinId: malaSkinId,
      deityImage: deity,
      malaSkinUrl: skinUrl,
    );
  }

  @override
  Future<List<MalaImageOption>> deityImages(String mantraId) async =>
      deityOptions;

  @override
  Future<List<MalaSkin>> skins() async => skinList;

  @override
  Future<MantraAppearance> appearance(String mantraId) async =>
      _current(mantraId);

  @override
  Future<MantraAppearance> updateAppearance(
    String mantraId, {
    AppearancePick? deityImage,
    AppearancePick? malaSkin,
  }) async {
    if (failSaves) throw Exception('save failed');
    patches.add({
      if (deityImage != null) 'deity_image_id': deityImage.id,
      if (malaSkin != null) 'mala_skin_id': malaSkin.id,
    });
    if (deityImage != null) deityImageId = deityImage.id;
    if (malaSkin != null) malaSkinId = malaSkin.id;
    return _current(mantraId);
  }
}

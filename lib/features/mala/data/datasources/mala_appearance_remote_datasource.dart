import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/config/api_config.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_image_option.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra_appearance.dart';
import 'package:flutter_pecha/features/mala/domain/repositories/mala_appearance_repository.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';

/// [MalaAppearanceRepository] over the v2 API. Errors are Dio's, unwrapped.
class MalaAppearanceRemoteDataSource implements MalaAppearanceRepository {
  MalaAppearanceRemoteDataSource({required this.dio});

  final Dio dio;

  String _appearancePath(String mantraId) =>
      '${ApiConfig.userMantrasV2Path}/$mantraId/appearance';

  /// `GET /mantras/{id}/images`, `deity_images` only.
  @override
  Future<List<MalaImageOption>> deityImages(String mantraId) async {
    final response = await dio.get<Map<String, dynamic>>(
      '${ApiConfig.mantrasV2Path}/$mantraId/images',
    );
    final items = response.data?['deity_images'];
    if (items is! List) return const [];
    final parsed = <({int order, MalaImageOption option})>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final imageJson = item['image'];
      if (id is! String || imageJson is! Map<String, dynamic>) continue;
      final image = ResponsiveImage.fromJson(imageJson);
      if (image.isEmpty) continue;
      parsed.add((
        order: (item['display_order'] as num?)?.toInt() ?? parsed.length,
        option: MalaImageOption(
          id: id,
          image: image,
          isDefault: item['is_default'] == true,
        ),
      ));
    }
    // Stable sort, so equal orders keep the server's order.
    final indexed =
        parsed.indexed.toList()..sort((a, b) {
          final byOrder = a.$2.order.compareTo(b.$2.order);
          return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
        });
    return [for (final entry in indexed) entry.$2.option];
  }

  /// `GET /mala-skins`.
  @override
  Future<List<MalaSkin>> skins() async {
    final response = await dio.get<Map<String, dynamic>>(
      ApiConfig.malaSkinsV2Path,
    );
    final items = response.data?['mala_skins'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic> &&
            item['id'] is String &&
            item['url'] is String &&
            (item['url'] as String).isNotEmpty)
          MalaSkin(
            id: item['id'] as String,
            name: item['name'] as String? ?? '',
            url: item['url'] as String,
            isDefault: item['default'] == true || item['is_default'] == true,
          ),
    ];
  }

  @override
  Future<MantraAppearance> appearance(String mantraId) async {
    final response = await dio.get<Map<String, dynamic>>(
      _appearancePath(mantraId),
    );
    return _parseAppearance(mantraId, response.data);
  }

  @override
  Future<MantraAppearance> updateAppearance(
    String mantraId, {
    AppearancePick? deityImage,
    AppearancePick? malaSkin,
  }) async {
    final response = await dio.patch<Map<String, dynamic>>(
      _appearancePath(mantraId),
      data: {
        if (deityImage != null) 'deity_image_id': deityImage.id,
        if (malaSkin != null) 'mala_skin_id': malaSkin.id,
      },
    );
    return _parseAppearance(mantraId, response.data);
  }

  static MantraAppearance _parseAppearance(
    String mantraId,
    Map<String, dynamic>? json,
  ) {
    final deityJson = json?['deity_image'];
    final deityImage =
        deityJson is Map<String, dynamic>
            ? ResponsiveImage.fromJson(deityJson)
            : null;
    final malaUrl = json?['mala_skin_url'] as String?;
    return MantraAppearance(
      mantraId: json?['mantra_id'] as String? ?? mantraId,
      deityImageId: json?['deity_image_id'] as String?,
      malaSkinId: json?['mala_skin_id'] as String?,
      deityImage: deityImage == null || deityImage.isEmpty ? null : deityImage,
      malaSkinUrl: malaUrl == null || malaUrl.isEmpty ? null : malaUrl,
    );
  }
}

import 'dart:typed_data';

import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_space_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/utils/connect_ended_utils.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_accumulator_providers.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/group_accumulation_counts_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Key for the counts state of one group accumulation counted with its own
/// mantra, kept apart from every preset-keyed state so unrelated
/// accumulations never share it.
String groupMantraCountsKey(String groupAccumulatorId) =>
    'group:$groupAccumulatorId';

/// A group accumulation counted on the mala with its own mantra, such as a
/// space mantra that the public preset list never contains.
class SpaceMantraItem {
  const SpaceMantraItem(this.accumulation, this.mantra);

  final GroupAccumulator accumulation;
  final MantraText mantra;

  static SpaceMantraItem? from(GroupAccumulator accumulation) {
    final mantra = accumulation.mantra;
    return mantra == null ? null : SpaceMantraItem(accumulation, mantra);
  }

  String get countsKey => groupMantraCountsKey(accumulation.id);

  String get title {
    final title = mantra.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return accumulation.title;
  }

  /// Drawing-only stand-in for the mantra carousel. Its [Mantra.presetId] is
  /// [countsKey], never a real preset id, so it must not be passed to a
  /// preset-keyed provider.
  Mantra get displayMantra => Mantra(
    presetId: countsKey,
    beadImageUrl: mantra.beadImageUrl,
    metadata: [AccumulatorMetadata(language: 'en', name: title)],
    mantra: mantra,
  );
}

/// Mantra accumulations the member has joined in their spaces and can still
/// count into. Each space's list already carries the resolved mantra.
///
/// Whether one is shown as its own carousel item or through its preset is
/// decided against the catalogue by the mala screen, so this list does not
/// depend on the catalogue.
final joinedSpaceMantrasProvider =
    FutureProvider.autoDispose<List<SpaceMantraItem>>((ref) async {
      final spaces = ref.watch(joinedSpacesProvider).spaces;
      if (spaces.isEmpty) return const [];

      final repository = ref.watch(groupAccumulatorRepositoryProvider);
      final language = ref.watch(contentLanguageProvider);
      final pages = await Future.wait(
        spaces.map(
          (space) => repository.getGroupAccumulators(
            space.id,
            skip: 0,
            limit: 50,
            language: language,
          ),
        ),
      );

      final now = DateTime.now();
      final seen = <String>{};
      final items = <SpaceMantraItem>[];
      for (final page in pages) {
        // A space whose list failed is left out rather than failing all.
        final accumulations = page.fold(
          (_) => const <GroupAccumulator>[],
          (page) => page.accumulators,
        );
        for (final accumulation in accumulations) {
          if (!accumulation.hasJoined ||
              accumulation.hasTextContent ||
              isPastEndDate(accumulation.endDate, now) ||
              !seen.add(accumulation.id)) {
            continue;
          }
          final item = SpaceMantraItem.from(accumulation);
          if (item != null) items.add(item);
        }
      }
      return items;
    });

/// Seeds one group accumulation's count from the server into its counts
/// state, since the server ignores a lower `current_count` and chants counted
/// on a stale base would be lost. Resolves false when the fetch failed; the
/// local count is used then, as in preset mode.
final groupMantraCountSeedProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, groupAccumulatorId) async {
      final counts = ref.watch(
        groupAccumulationCountsProvider(
          groupMantraCountsKey(groupAccumulatorId),
        ).notifier,
      );
      final language = ref.read(contentLanguageProvider);
      final result = await ref
          .read(groupAccumulatorRepositoryProvider)
          .refreshGroupAccumulator(groupAccumulatorId, language: language);
      final serverTotal = result.fold(
        (_) => null,
        (detail) => detail.user?.totalCount ?? 0,
      );
      if (serverTotal == null) return false;
      await counts.mergeFromServerCounts({groupAccumulatorId: serverTotal});
      return true;
    });

/// Bead artwork for [item]: the accumulation's resolved skin first, then the
/// mantra's default. Null while loading or when neither downloads.
Uint8List? watchSpaceMantraBeadBytes(WidgetRef ref, SpaceMantraItem item) {
  final urls = <String>{
    for (final url in [
      item.accumulation.malaImageUrl,
      item.mantra.beadImageUrl,
    ])
      if (url != null && url.isNotEmpty) url,
  };
  for (final url in urls) {
    final image = ref.watch(malaBeadImageBytesProvider(url));
    if (image.isLoading) return null;
    final bytes = image.valueOrNull;
    if (bytes != null) return bytes;
  }
  return null;
}

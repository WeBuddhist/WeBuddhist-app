import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_space_providers.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_pecha/features/group_profile/domain/repositories/group_accumulator_repository.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_accumulator_providers.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/space_mantra_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements GroupAccumulatorRepositoryInterface {
  _Repository(this.pages);

  final Map<String, Either<Failure, List<GroupAccumulator>>> pages;

  @override
  Future<Either<Failure, GroupAccumulatorsPage>> getGroupAccumulators(
    String groupId, {
    required int skip,
    required int limit,
    required String language,
  }) async {
    return pages[groupId]!.map(
      (list) => GroupAccumulatorsPage(
        accumulators: list,
        total: list.length,
        skip: skip,
        limit: limit,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _mantra = MantraText(
  id: 'space-mantra',
  text: 'ཨོཾ་ཨཀྵོ་བྷྱ་ཧཱུྃ།',
  title: 'Akshobhya',
  pronunciation: 'Om Akshobhya Hum',
);

GroupAccumulator _accumulation(
  String id, {
  bool joined = true,
  MantraText? mantra = _mantra,
  String? textId,
  DateTime? endDate,
}) => GroupAccumulator(
  id: id,
  presetAccumulatorId: '',
  textId: textId,
  mantraId: mantra?.id,
  mantra: mantra,
  groupId: 'space-1',
  title: 'Title $id',
  isJoined: joined,
  endDate: endDate,
);

Future<List<SpaceMantraItem>> _read(
  Map<String, Either<Failure, List<GroupAccumulator>>> pages,
) {
  final container = ProviderContainer(
    overrides: [
      joinedSpacesProvider.overrideWithValue(
        JoinedSpaces(
          spaces: [for (final id in pages.keys) GroupProfile(id: id)],
          isLoading: false,
        ),
      ),
      groupAccumulatorRepositoryProvider.overrideWithValue(_Repository(pages)),
      contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
    ],
  );
  addTearDown(container.dispose);
  return container.read(joinedSpaceMantrasProvider.future);
}

void main() {
  group('joinedSpaceMantrasProvider', () {
    test('lists joined, open mantra accumulations from every space', () async {
      final items = await _read({
        'space-1': Right([
          _accumulation('a'),
          _accumulation('not-joined', joined: false),
          _accumulation('text', textId: 'text-1'),
          _accumulation('no-mantra', mantra: null),
          _accumulation('ended', endDate: DateTime(2000)),
        ]),
        'space-2': Right([_accumulation('b'), _accumulation('a')]),
      });

      expect(items.map((i) => i.accumulation.id), ['a', 'b']);
    });

    test('a space whose list fails is left out', () async {
      final items = await _read({
        'space-1': const Left(ServerFailure('down')),
        'space-2': Right([_accumulation('b')]),
      });

      expect(items.map((i) => i.accumulation.id), ['b']);
    });
  });

  group('SpaceMantraItem', () {
    test('its carousel stand-in never names a real preset', () {
      final item = SpaceMantraItem.from(_accumulation('a'))!;

      expect(item.displayMantra.presetId, 'group:a');
      expect(item.displayMantra.tibetan, _mantra.text);
      expect(item.title, 'Akshobhya');
    });

    test('falls back to the accumulation title when the mantra has none', () {
      final item =
          SpaceMantraItem.from(
            _accumulation(
              'a',
              mantra: const MantraText(id: 'm', text: 'ཨོཾ'),
            ),
          )!;

      expect(item.title, 'Title a');
      expect(item.displayMantra.localizedName('en'), 'Title a');
    });
  });
}

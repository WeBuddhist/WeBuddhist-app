import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_accumulator_practice_launcher.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_test/flutter_test.dart';

const _spaceMantra = MantraText(
  id: 'space-mantra',
  text: 'ཨོཾ་ཨཀྵོ་བྷྱ་ཧཱུྃ།',
  pronunciation: 'Om Akshobhya Hum',
);

const _presetMantra = MantraText(
  id: 'preset-mantra',
  text: 'ཨོཾ་མ་ཎི་པདྨེ་ཧཱུྃ།',
  pronunciation: 'Om Mani Padme Hum',
);

const _catalogue = [Mantra(presetId: 'preset-1', mantra: _presetMantra)];

GroupAccumulatorDetail _detail({
  String presetId = '',
  String? textId,
  String? mantraId,
  MantraText? mantra,
}) => GroupAccumulatorDetail(
  id: 'acc-1',
  presetAccumulatorId: presetId,
  textId: textId,
  mantraId: mantraId,
  mantra: mantra,
  groupId: 'group-1',
  title: 'Accumulation',
);

void main() {
  group('resolveGroupAccumulatorPracticeMode', () {
    test('a text accumulation opens the reader', () {
      expect(
        resolveGroupAccumulatorPracticeMode(
          _detail(textId: 'text-1', presetId: 'preset-1'),
          catalogue: _catalogue,
        ),
        GroupAccumulatorPracticeMode.reader,
      );
    });

    test('a public preset whose mantra matches keeps the preset mala', () {
      expect(
        resolveGroupAccumulatorPracticeMode(
          _detail(
            presetId: 'preset-1',
            mantraId: 'preset-mantra',
            mantra: _presetMantra,
          ),
          catalogue: _catalogue,
        ),
        GroupAccumulatorPracticeMode.preset,
      );
    });

    test('a space mantra with no preset opens single-accumulation mode', () {
      expect(
        resolveGroupAccumulatorPracticeMode(
          _detail(mantraId: 'space-mantra', mantra: _spaceMantra),
          catalogue: _catalogue,
        ),
        GroupAccumulatorPracticeMode.groupMantra,
      );
    });

    test('an own mantra that differs from the linked preset is not the '
        "preset's mala", () {
      expect(
        resolveGroupAccumulatorPracticeMode(
          _detail(
            presetId: 'preset-1',
            mantraId: 'space-mantra',
            mantra: _spaceMantra,
          ),
          catalogue: _catalogue,
        ),
        GroupAccumulatorPracticeMode.groupMantra,
      );
    });

    test('catalogue not loaded yet uses single-accumulation mode', () {
      expect(
        resolveGroupAccumulatorPracticeMode(
          _detail(
            presetId: 'preset-1',
            mantraId: 'preset-mantra',
            mantra: _presetMantra,
          ),
        ),
        GroupAccumulatorPracticeMode.groupMantra,
      );
    });

    test('old data with a preset but no mantra falls back to the preset', () {
      expect(
        resolveGroupAccumulatorPracticeMode(
          _detail(presetId: 'preset-1', mantraId: 'preset-mantra'),
        ),
        GroupAccumulatorPracticeMode.preset,
      );
    });

    test('nothing to open is unavailable', () {
      expect(
        resolveGroupAccumulatorPracticeMode(_detail(), catalogue: _catalogue),
        GroupAccumulatorPracticeMode.unavailable,
      );
    });
  });
}

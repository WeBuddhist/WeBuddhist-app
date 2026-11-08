import 'package:flutter_pecha/features/onboarding/data/models/tradition_models.dart';
import 'package:flutter_pecha/features/onboarding/domain/tradition_tag_ids.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = [
  Tradition(code: 'chinese', name: 'Mahayana', libraryTagId: 'TAG_CH'),
  Tradition(code: 'pali', name: 'Theravada', libraryTagId: 'TAG_PA'),
  Tradition(code: 'tibetan', name: 'Vajrayana', libraryTagId: 'TAG_TI'),
];

List<String> _resolve(
  Set<String> codes, {
  List<Tradition> catalog = _catalog,
}) => resolveTraditionTagIds(catalog: catalog, selectedCodes: codes);

void main() {
  test('one tradition gives its tag', () {
    expect(_resolve({'tibetan'}), ['TAG_TI']);
  });

  test('two traditions give both tags in catalogue order', () {
    expect(_resolve({'tibetan', 'pali'}), ['TAG_PA', 'TAG_TI']);
  });

  test('nothing selected means no filter', () {
    expect(_resolve({}), isEmpty);
  });

  test('every tagged tradition selected means no filter', () {
    expect(_resolve({'chinese', 'pali', 'tibetan'}), isEmpty);
  });

  test('a selected code missing from the catalogue is ignored', () {
    expect(_resolve({'tibetan', 'zen'}), ['TAG_TI']);
    expect(_resolve({'zen'}), isEmpty);
  });

  test('traditions without a tag cannot filter', () {
    const catalog = [
      Tradition(code: 'chinese', name: 'Mahayana'),
      Tradition(code: 'pali', name: 'Theravada', libraryTagId: 'TAG_PA'),
      Tradition(code: 'tibetan', name: 'Vajrayana', libraryTagId: 'TAG_TI'),
    ];
    // Chinese has no tag: picking it with Tibetan filters by Tibetan alone.
    expect(_resolve({'chinese', 'tibetan'}, catalog: catalog), ['TAG_TI']);
    // Both tagged traditions picked is "everything" even with Chinese out.
    expect(_resolve({'pali', 'tibetan'}, catalog: catalog), isEmpty);
    expect(_resolve({'chinese'}, catalog: catalog), isEmpty);
  });

  test('a catalogue with no tags at all (dev) never filters', () {
    const catalog = [
      Tradition(code: 'pali', name: 'Theravada'),
      Tradition(code: 'tibetan', name: 'Vajrayana'),
    ];
    expect(_resolve({'tibetan'}, catalog: catalog), isEmpty);
  });

  test('the result cannot be mutated by a caller', () {
    expect(() => _resolve({'tibetan'}).add('x'), throwsUnsupportedError);
  });
}

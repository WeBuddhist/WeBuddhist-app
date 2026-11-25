import 'package:flutter_pecha/features/library/data/adapters/library_recitations_remote_datasource.dart';
import 'package:flutter_pecha/features/library/data/models/library_text.dart';
import 'package:flutter_pecha/features/practice/data/datasource/my_recitation_collections_remote_datasource.dart';
import 'package:flutter_pecha/features/recitation/data/datasource/recitations_remote_datasource.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../library_test_server.dart';

void main() {
  test('a library text reads its audio ids', () {
    final recorded = LibraryText.fromJson({
      ...textJson('T1', editions: ['E1']),
      'audios': ['A1'],
    });
    final silent = LibraryText.fromJson(textJson('T2', editions: ['E2']));

    expect(recorded.audioIds, ['A1']);
    expect(silent.audioIds, isEmpty);
  });

  test('a chant the library recorded is listed with audio', () async {
    final server = LibraryTestServer({
      '/v2/texts':
          (_) => jsonBody(
            pageJson([
              {
                ...textJson('T1', editions: ['E1']),
                'audios': ['A1'],
              },
              textJson('T2', editions: ['E2']),
            ], limit: 20),
          ),
    });
    final datasource = LibraryRecitationsRemoteDatasource(
      library: server.repository(),
      collections: MyRecitationCollectionsRemoteDatasource(dio: server.dio()),
      tagId: 'TAG',
    );

    final page = await datasource.fetchRecitationsPage(
      queryParams: RecitationsQueryParams(language: 'bo', skip: 0, limit: 20),
    );

    expect(page.recitations.map((r) => (r.textId, r.hasAudio)), [
      ('E1', true),
      ('E2', false),
    ]);
  });

  test('the audio flag survives the cached JSON', () {
    final withAudio = RecitationModel(textId: 'E1', title: 'One', hasAudio: true);
    final without = RecitationModel(textId: 'E2', title: 'Two');

    expect(RecitationModel.fromJson(withAudio.toJson()).hasAudio, isTrue);
    expect(RecitationModel.fromJson(without.toJson()).hasAudio, isFalse);
    expect(without.toJson().containsKey('has_audio'), isFalse);
  });
}

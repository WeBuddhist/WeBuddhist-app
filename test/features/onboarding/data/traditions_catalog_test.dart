import 'package:flutter_pecha/features/onboarding/data/datasource/onboarding_remote_datasource.dart';
import 'package:flutter_pecha/features/onboarding/data/models/tradition_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../library/library_test_server.dart';

void main() {
  test('parses the catalogue as served by GET /traditions', () async {
    final server = LibraryTestServer({
      '/traditions':
          (_) => jsonBody({
            'traditions': [
              {
                'code': 'chinese',
                'name': 'Mahayana',
                'regions': ['China', 'Korea'],
                'library_tag_id': 'TAG_CH',
              },
              {
                'code': 'pali',
                'name': 'Theravada',
                'regions': ['Sri Lanka'],
                'library_tag_id': null,
              },
              {'code': 'tibetan', 'name': 'Vajrayana', 'library_tag_id': ''},
            ],
          }),
    });

    final traditions =
        await OnboardingRemoteDatasource(dio: server.dio()).fetchTraditions();

    expect(server.requests.single.path, '/traditions');
    expect(server.requests.single.queryParameters, isEmpty);
    expect(traditions.map((t) => t.code), ['chinese', 'pali', 'tibetan']);
    expect(traditions.first.name, 'Mahayana');
    expect(traditions.first.regions, ['China', 'Korea']);
    expect(traditions.first.libraryTagId, 'TAG_CH');
    // Unset in the CMS (dev) and blank both read as "no tag".
    expect(traditions[1].libraryTagId, isNull);
    expect(traditions[2].libraryTagId, isNull);
    expect(traditions[2].regions, isEmpty);
  });

  test('a tradition without a code is rejected, a bad body throws', () async {
    expect(
      () => Tradition.fromJson({'name': 'x'}),
      throwsA(isA<FormatException>()),
    );
    final server = LibraryTestServer({
      '/traditions': (_) => jsonBody({'traditions': 'nope'}),
    });
    await expectLater(
      OnboardingRemoteDatasource(dio: server.dio()).fetchTraditions(),
      throwsA(anything),
    );
  });
}

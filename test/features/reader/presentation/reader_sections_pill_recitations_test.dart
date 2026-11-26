import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/reader/presentation/providers/reader_text_size_provider.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_content/reader_sections_pill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_local_storage.dart';

Widget _app(Widget child) => ProviderScope(
  overrides: [
    readerTextSizeProvider.overrideWith(
      (ref) => ReaderTextSizeNotifier(localStorageService: FakeLocalStorage()),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  // Tibetan uses a bundled font, so no Google Fonts lookup runs in tests.
  const title = 'བསྟོད་པ།';
  const recitations = Key('reader_sections_pill_recitation_count');

  Widget pill({int recitationCount = 0}) => ReaderSectionsPill(
    title: title,
    language: 'bo',
    numeralLanguage: 'en',
    position: 5,
    total: 15,
    recitationCount: recitationCount,
    onTap: () {},
  );

  testWidgets('no recitation count before any is counted', (tester) async {
    await tester.pumpWidget(_app(pill()));

    expect(find.byKey(recitations), findsNothing);
  });

  testWidgets('shows the running recitation count after the place', (
    tester,
  ) async {
    await tester.pumpWidget(_app(pill(recitationCount: 4)));

    expect(tester.widget<Text>(find.byKey(recitations)).data, '· ×4');
  });
}

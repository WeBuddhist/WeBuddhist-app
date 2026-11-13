import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_actions/reader_verse_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_local_storage.dart';

Future<void> _pump(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(FakeLocalStorage()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: ReaderNoResources()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('in the interface language', (tester) async {
    await _pump(tester, const Locale('bo'));

    expect(
      find.text('ཚིགས་བཅད་འདིའི་འགྲེལ་བ་དང་པར་གཞི་མི་འདུག'),
      findsOneWidget,
    );
  });

  testWidgets('a verse with nothing says so and that more are coming', (
    tester,
  ) async {
    await _pump(tester, const Locale('en'));

    expect(find.byIcon(AppAssets.bookOpen), findsOneWidget);
    expect(
      find.text('No commentaries or versions available for this segment'),
      findsOneWidget,
    );
    expect(
      find.text('We add new texts regularly; check back soon'),
      findsOneWidget,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/connect/domain/entities/space_sort.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_discover_spaces.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('picking a sort updates the shared choice and the pill', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ConnectLookingForHeader()),
        ),
      ),
    );

    expect(find.text('Looking for'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);

    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();

    // The pill and the checked menu row both say Popular.
    expect(find.text('Popular'), findsNWidgets(2));
    expect(find.text('Newly added'), findsOneWidget);
    expect(find.text('Most active'), findsOneWidget);

    await tester.tap(find.text('Most active'));
    await tester.pumpAndSettle();

    expect(container.read(discoverSpaceSortProvider), SpaceSort.mostActive);
    expect(find.text('Most active'), findsOneWidget);
    expect(find.text('Popular'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_notifier.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_accumulator_practice_launcher.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

const _taraMantra = MantraText(id: 'tara-mantra', text: 'ཨོཾ་ཏཱ་རེ།');
const _spaceMantra = MantraText(id: 'space-mantra', text: 'ཨོཾ་ཨཀྵོ་བྷྱ་ཧཱུྃ།');

GroupAccumulatorDetail _detail({
  String presetId = '',
  MantraText? mantra,
  String? textId,
}) => GroupAccumulatorDetail(
  id: 'acc-1',
  presetAccumulatorId: presetId,
  mantra: mantra,
  mantraId: mantra?.id,
  textId: textId,
  groupId: 'space-1',
  title: 'Space accumulation',
);

/// Taps a button that calls [pushGroupAccumulatorMala] and returns what the
/// `/mala` route was given, or null when nothing was pushed.
Future<({Object? extra, bool opened})> _recite(
  WidgetTester tester,
  GroupAccumulatorDetail detail,
) async {
  Object? pushedExtra;
  var opened = false;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder:
            (context, _) => Scaffold(
              body: Consumer(
                builder:
                    (context, ref, _) => TextButton(
                      onPressed: () async {
                        opened = await pushGroupAccumulatorMala(
                          context,
                          ref,
                          detail,
                          ended: false,
                        );
                      },
                      child: const Text('Recite'),
                    ),
              ),
            ),
      ),
      GoRoute(
        path: '/mala',
        builder: (context, state) {
          pushedExtra = state.extra;
          return const Scaffold(body: Text('mala'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        malaCatalogueProvider.overrideWith(
          () => ScreenCacheNotifier.fixed(
            const Right([Mantra(presetId: 'tara', mantra: _taraMantra)]),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.tap(find.text('Recite'));
  await tester.pumpAndSettle();
  if (pushedExtra != null) {
    // Pop back so the push future (and `opened`) completes.
    router.pop();
    await tester.pumpAndSettle();
  }
  return (extra: pushedExtra, opened: opened);
}

void main() {
  testWidgets('a preset accumulation opens the preset mala', (tester) async {
    final r = await _recite(
      tester,
      _detail(presetId: 'tara', mantra: _taraMantra),
    );
    final extra = r.extra! as Map<String, dynamic>;
    expect(extra['presetId'], 'tara');
    expect(extra['groupAccumulatorId'], 'acc-1');
    expect(extra.containsKey('groupAccumulator'), isFalse);
    expect(r.opened, isTrue);
  });

  testWidgets('a space mantra opens single-accumulation mode', (tester) async {
    final detail = _detail(mantra: _spaceMantra);
    final r = await _recite(tester, detail);
    final extra = r.extra! as Map<String, dynamic>;
    expect(extra['groupAccumulator'], same(detail));
    expect(r.opened, isTrue);
  });

  testWidgets('nothing to open shows a message and opens nothing', (
    tester,
  ) async {
    final r = await _recite(tester, _detail());
    expect(r.extra, isNull);
    expect(r.opened, isFalse);
    expect(
      find.text("This practice can't be opened right now."),
      findsOneWidget,
    );
  });
}

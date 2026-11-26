import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/poems/domain/entities/poem.dart';
import 'package:flutter_pecha/features/poems/presentation/widgets/poem_preview_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage(super.code);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _poem = Poem(
  id: 'p1',
  title: 'A title long enough to wrap onto a second line in the card',
  content: 'First line\nSecond line\nThird line\nFourth line\nFifth line',
  authorName: 'An author',
);

Future<void> _pump(
  WidgetTester tester, {
  required double scale,
  required String language,
}) {
  const width = 320.0;
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentLanguageProvider.overrideWith(
          (ref) => _FixedContentLanguage(language),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Builder(
            builder:
                (context) => Scaffold(
                  body: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        height: PoemPreviewCard.heightFor(
                          width,
                          MediaQuery.textScalerOf(context),
                        ),
                        child: PoemPreviewCard(poem: _poem, onTap: () {}),
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('the text area is the design 224 at 1x and grows with text size', () {
    expect(PoemPreviewCard.textAreaHeightFor(TextScaler.noScaling), 224);
    expect(
      PoemPreviewCard.textAreaHeightFor(const TextScaler.linear(2)),
      greaterThan(224),
    );
  });

  for (final language in ['en', 'bo']) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('a 2-line title fits at ${scale}x ($language)', (
        tester,
      ) async {
        await _pump(tester, scale: scale, language: language);
        expect(tester.takeException(), isNull);
        expect(find.text('An author'), findsOneWidget);
      });
    }
  }
}

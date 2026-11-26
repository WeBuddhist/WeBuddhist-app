import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/services/upgrade/force_update_dialog.dart';
import 'package:flutter_pecha/core/services/upgrade/force_update_gate.dart';
import 'package:flutter_pecha/core/services/upgrade/upgrade_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _title = _en.force_update_title;
final _button = _en.force_update_button;

final _mobile = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

/// Mirrors the production setup in `main.dart`: a GoRouter app with the gate
/// mounted in `MaterialApp.router`'s `builder`, above the navigator.
class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final updates = StreamController<bool>();
  final platformCalls = <String>[];
  var storeOpens = 0;
  var homeTaps = 0;
  late final GoRouter router;

  Future<void> pump({bool? updateAvailable}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      updates.close();
    });

    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Counter(),
                  TextButton(
                    onPressed: () => homeTaps++,
                    child: const Text('home button'),
                  ),
                ],
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: 'details',
              builder: (context, state) =>
                  const Scaffold(body: Text('details page')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateAvailableProvider.overrideWith((ref) => updates.stream),
          openAppStoreProvider.overrideWithValue(() => storeOpens++),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) =>
              ForceUpdateGate(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    if (updateAvailable != null) await emit(updateAvailable);
  }

  Future<void> emit(bool updateAvailable) async {
    updates.add(updateAvailable);
    await tester.pumpAndSettle();
  }

  /// Sends the Android system back event the engine sends on a back press.
  Future<void> pressSystemBack() async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  bool get appClosed => platformCalls.contains('SystemNavigator.pop');
}

/// Stateful widget used to detect whether the routes behind the gate were
/// remounted (which would reset this counter).
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _count++),
    child: Text('count $_count'),
  );
}

void main() {
  group('ForceUpdateGate', () {
    testWidgets('lets the app through when no update is available', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: false);

      expect(find.byType(ForceUpdateDialog), findsNothing);
      await tester.tap(find.text('home button'));
      expect(h.homeTaps, 1);
    }, variant: _mobile);

    testWidgets('lets the app through while the store check is pending', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();

      expect(find.byType(ForceUpdateDialog), findsNothing);
      expect(find.text('home button'), findsOneWidget);
    }, variant: _mobile);

    testWidgets('shows the update modal when an update is available', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: true);

      expect(find.byType(ForceUpdateDialog), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_en.force_update_message), findsOneWidget);
      expect(find.text(_button), findsOneWidget);
    }, variant: _mobile);

    testWidgets('blocks taps on the app behind the modal', (tester) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: true);

      await tester.tap(find.text('home button'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(h.homeTaps, 0);
    }, variant: _mobile);

    testWidgets('tapping outside the dialog does not dismiss it', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: true);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width - 5, size.height - 5));
      await tester.pumpAndSettle();

      expect(find.byType(ForceUpdateDialog), findsOneWidget);
    }, variant: _mobile);

    testWidgets('"Update now" opens the store and keeps the modal up', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: true);

      await tester.tap(find.text(_button));
      await tester.pumpAndSettle();

      expect(h.storeOpens, 1);
      expect(find.byType(ForceUpdateDialog), findsOneWidget);
    }, variant: _mobile);

    testWidgets('system back does not pop the route behind the modal', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: false);
      h.router.go('/details');
      await tester.pumpAndSettle();
      await h.emit(true);

      await h.pressSystemBack();

      expect(find.text('details page'), findsOneWidget);
      expect(find.byType(ForceUpdateDialog), findsOneWidget);
    }, variant: _mobile);

    testWidgets('system back on the root route does not close the app', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: true);

      await h.pressSystemBack();

      expect(h.appClosed, isFalse);
      expect(find.byType(ForceUpdateDialog), findsOneWidget);
    }, variant: _mobile);

    // Control for the two tests above: proves the simulated back press does
    // pop and close when the gate is not blocking.
    testWidgets('system back works normally when no update is required', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: false);
      h.router.go('/details');
      await tester.pumpAndSettle();

      await h.pressSystemBack();
      expect(find.text('home button'), findsOneWidget);

      await h.pressSystemBack();
      expect(h.appClosed, isTrue);
    }, variant: _mobile);

    testWidgets(
      'blocks mid-session when a later store check finds an update',
      (tester) async {
        final h = _Harness(tester);
        await h.pump(updateAvailable: false);
        await tester.tap(find.text('count 0'));
        await tester.pumpAndSettle();

        await h.emit(true);

        expect(find.byType(ForceUpdateDialog), findsOneWidget);
        // The routes behind the gate are kept, not remounted.
        expect(find.text('count 1'), findsOneWidget);
      },
      variant: _mobile,
    );

    testWidgets('unblocks when a later check finds no update', (tester) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: true);

      await h.emit(false);

      expect(find.byType(ForceUpdateDialog), findsNothing);
      await tester.tap(find.text('home button'));
      expect(h.homeTaps, 1);
    }, variant: _mobile);

    testWidgets('hides the app behind the modal from focus and semantics', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(updateAvailable: true);

      Finder inGate(Type type) => find
          .descendant(
            of: find.byType(ForceUpdateGate),
            matching: find.byType(type),
          )
          .first;
      final gateSemantics = tester.widget<ExcludeSemantics>(
        inGate(ExcludeSemantics),
      );
      final gateFocus = tester.widget<ExcludeFocus>(inGate(ExcludeFocus));
      expect(gateSemantics.excluding, isTrue);
      expect(gateFocus.excluding, isTrue);
    }, variant: _mobile);

    testWidgets(
      'never blocks on non-mobile platforms',
      (tester) async {
        final h = _Harness(tester);
        await h.pump(updateAvailable: true);

        expect(find.byType(ForceUpdateDialog), findsNothing);
        await tester.tap(find.text('home button'));
        expect(h.homeTaps, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('updateAvailableProvider', () {
    test('never reports an update outside release builds', () async {
      expect(kReleaseMode, isFalse);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final value = await container.read(updateAvailableProvider.future);

      expect(value, isFalse);
    });
  });
}

import 'package:flutter_pecha/features/reader/presentation/utils/deferred_recitation.dart';
import 'package:flutter_test/flutter_test.dart';

// testWidgets runs on a fake clock, so tester.pump moves the timers on.
void main() {
  const window = Duration(seconds: 5);

  late int commits;
  late DeferredRecitation pending;

  setUp(() {
    commits = 0;
    pending = DeferredRecitation(window: window, onCommit: () => commits++);
  });

  testWidgets('a held recitation is counted once the window closes', (
    tester,
  ) async {
    pending.hold();
    expect(pending.isPending, isTrue);
    await tester.pump(const Duration(seconds: 4));
    expect(commits, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(commits, 1);
    expect(pending.isPending, isFalse);
  });

  testWidgets('Undo drops the held recitation; nothing is counted', (
    tester,
  ) async {
    pending.hold();
    expect(pending.undo(), isTrue);
    await tester.pump(const Duration(seconds: 10));

    expect(commits, 0);
    expect(pending.isPending, isFalse);
  });

  testWidgets('Undo after the window closed changes nothing', (tester) async {
    pending.hold();
    await tester.pump(window);

    expect(pending.undo(), isFalse);
    expect(commits, 1);
  });

  testWidgets('holding again counts the one already held first', (
    tester,
  ) async {
    pending.hold();
    pending.hold();
    expect(commits, 1);
    expect(pending.isPending, isTrue);

    await tester.pump(window);
    expect(commits, 2);
  });

  testWidgets('commit counts now and only once', (tester) async {
    pending.commit();
    expect(commits, 0, reason: 'nothing was held');

    pending.hold();
    pending.commit();
    pending.commit();
    await tester.pump(window);

    expect(commits, 1);
  });
}

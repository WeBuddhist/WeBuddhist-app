import 'package:flutter_pecha/core/analytics/foreground_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds calls until opened, then sends them in order', () async {
    final gate = ForegroundGate();
    final sent = <String>[];

    await gate.run(() async => sent.add('a'));
    await gate.run(() async => sent.add('b'));
    expect(sent, isEmpty);

    await gate.open();
    expect(sent, ['a', 'b']);

    await gate.run(() async => sent.add('c'));
    expect(sent, ['a', 'b', 'c']);
  });

  test('a call made while the queue drains goes after it', () async {
    final gate = ForegroundGate();
    final sent = <String>[];

    await gate.run(() async {
      await gate.run(() async => sent.add('late'));
      sent.add('first');
    });
    await gate.run(() async => sent.add('second'));

    await gate.open();
    expect(sent, ['first', 'second', 'late']);
    expect(gate.isOpen, isTrue);
  });

  test('a headless run that never opens sends nothing', () async {
    final gate = ForegroundGate(maxPending: 2);
    final sent = <String>[];

    for (final name in ['a', 'b', 'c']) {
      await gate.run(() async => sent.add(name));
    }
    expect(sent, isEmpty);
    expect(gate.pendingCount, 2, reason: 'oldest dropped past the cap');

    await gate.open();
    expect(sent, ['b', 'c']);
  });

  test('discarded calls are never sent', () async {
    final gate = ForegroundGate();
    final sent = <String>[];

    await gate.run(() async => sent.add('old identity'));
    gate.discardPending();
    await gate.open();

    expect(sent, isEmpty);
  });

  test('a failing call does not stop the rest', () async {
    final gate = ForegroundGate();
    final sent = <String>[];

    await gate.run(() async => throw Exception('boom'));
    await gate.run(() async => sent.add('after'));
    await gate.open();

    expect(sent, ['after']);
  });
}

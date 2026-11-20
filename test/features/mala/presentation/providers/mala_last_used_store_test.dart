import 'package:flutter_pecha/features/mala/presentation/providers/mala_last_used_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_carousel_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> prefs;
  late int writes;
  late DateTime now;

  MalaLastUsedStore store() => MalaLastUsedStore(
    read: (key) => prefs[key],
    write: (key, value) async {
      writes++;
      prefs[key] = value;
    },
    now: () => now,
  );

  setUp(() {
    prefs = {};
    writes = 0;
    now = DateTime.utc(2026, 11, 20, 9);
  });

  test('records and reads back the last preset per user', () async {
    final s = store();
    await s.record('u1', 'tara');
    await s.record('u2', 'mani');

    expect(s.read('u1'), MalaLastUsed(presetId: 'tara', at: now));
    expect(s.read('u2')?.presetId, 'mani');
    expect(store().read('u1')?.presetId, 'tara', reason: 'survives restart');
  });

  test('nothing for no user, an unknown user or a bad entry', () async {
    final s = store();
    await s.record(null, 'tara');
    expect(prefs, isEmpty);
    expect(s.read(null), isNull);
    expect(s.read('u1'), isNull);

    prefs['mala_last_used_preset_u1'] = 'not json';
    expect(s.read('u1'), isNull);
  });

  test('taps on the same preset are written at most every 30s', () async {
    final s = store();
    await s.record('u1', 'tara');
    now = now.add(const Duration(seconds: 10));
    await s.record('u1', 'tara');
    expect(writes, 1);

    now = now.add(const Duration(seconds: 25));
    await s.record('u1', 'tara');
    expect(writes, 2);
    expect(s.read('u1')?.at, now);
  });

  test('switching preset is written at once', () async {
    final s = store();
    await s.record('u1', 'tara');
    now = now.add(const Duration(seconds: 1));
    await s.record('u1', 'mani');
    expect(writes, 2);
    expect(s.read('u1')?.presetId, 'mani');
  });
}

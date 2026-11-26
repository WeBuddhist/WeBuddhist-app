import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_image_option.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_appearance_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/space_mantra_providers.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mala_fakes.dart';

const _own = ResponsiveImage(thumbnail: 'https://s3/own.jpg');
const _other = ResponsiveImage(thumbnail: 'https://s3/other.jpg');

const _mantra = Mantra(
  presetId: 'tara',
  mantra: MantraText(id: 'm1', text: 'om', deityImage: _own),
);

final _ownBead = Uint8List.fromList([1]);
final _skinBead = Uint8List.fromList([2]);
final _defaultBead = Uint8List.fromList([3]);

FakeMalaAppearanceRepository _server({
  String? deity,
  String? skin,
  bool defaultSkin = true,
}) => FakeMalaAppearanceRepository(
  deityOptions: const [
    MalaImageOption(id: 'own', image: _own, isDefault: true),
    MalaImageOption(id: 'other', image: _other),
  ],
  skinList: [
    if (defaultSkin)
      const MalaSkin(
        id: 'ellipse',
        name: 'ellipse',
        url: 'https://s3/ellipse',
        isDefault: true,
      ),
    const MalaSkin(id: 'bodhi', name: 'bodhi_seed', url: 'https://s3/bodhi'),
  ],
  deityImageId: deity,
  malaSkinId: skin,
);

const _beadsByUrl = {'https://s3/bodhi': 2, 'https://s3/ellipse': 3};

/// What the mala screen would draw for [_mantra].
typedef _Shown = ({ResponsiveImage? image, Uint8List? bead});

/// [mantra] and [ownBead] are what the accumulation itself holds.
Future<_Shown Function()> _pump(
  WidgetTester tester,
  FakeMalaAppearanceRepository server, {
  Mantra mantra = _mantra,
  Uint8List? ownBead,
}) async {
  final heldBead = ownBead ?? _ownBead;
  late _Shown shown;
  late WidgetRef widgetRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        malaAppearanceRepositoryProvider.overrideWithValue(server),
        malaBeadImageBytesProvider.overrideWith(
          (ref, url) async => switch (_beadsByUrl[url]) {
            2 => _skinBead,
            3 => _defaultBead,
            _ => null,
          },
        ),
        // Saving refreshes this list; keep it off the network.
        joinedSpaceMantrasProvider.overrideWith((ref) async => const []),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          widgetRef = ref;
          shown = (
            image: watchMalaMantraImage(ref, mantra),
            bead: watchMalaBeadBytes(ref, mantra.mantraId, heldBead),
          );
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  _ref = widgetRef;
  return () => shown;
}

late WidgetRef _ref;

void main() {
  testWidgets('without a pick, the mantra shows its default image and bead', (
    tester,
  ) async {
    final shown = await _pump(tester, _server());

    expect(shown().image, _own);
    expect(shown().bead, _defaultBead);
  });

  testWidgets('the accumulation bead stands in when there is no skin url', (
    tester,
  ) async {
    final shown = await _pump(tester, _server(defaultSkin: false));

    expect(shown().bead, _ownBead);
  });

  testWidgets('clearing a pick shows the default, not the earlier pick the '
      'accumulation still holds', (tester) async {
    // The accumulation was loaded while "other" and "bodhi" were picked.
    const picked = Mantra(
      presetId: 'tara',
      mantra: MantraText(id: 'm1', text: 'om', deityImage: _other),
    );
    final shown = await _pump(
      tester,
      _server(deity: 'other', skin: 'bodhi'),
      mantra: picked,
      ownBead: _skinBead,
    );

    final notifier = _ref.read(malaAppearanceProvider('m1').notifier);
    expect(await notifier.setDeityImage(null), isTrue);
    expect(await notifier.setMalaSkin(null), isTrue);
    await tester.pumpAndSettle();

    expect(shown().image, _own);
    expect(shown().bead, _defaultBead);
  });

  testWidgets('a saved pick replaces the image and bead', (tester) async {
    final shown = await _pump(tester, _server(deity: 'other', skin: 'bodhi'));

    expect(shown().image, _other);
    expect(shown().bead, _skinBead);
  });

  testWidgets('saving updates what is shown at once', (tester) async {
    final server = _server();
    final shown = await _pump(tester, server);

    final notifier = _ref.read(malaAppearanceProvider('m1').notifier);
    expect(await notifier.setDeityImage('other'), isTrue);
    expect(await notifier.setMalaSkin('bodhi'), isTrue);
    await tester.pumpAndSettle();

    expect(shown().image, _other);
    expect(shown().bead, _skinBead);
  });

  testWidgets('a failed save returns false and changes nothing', (
    tester,
  ) async {
    final server = _server()..failSaves = true;
    final shown = await _pump(tester, server);

    final saved = await _ref
        .read(malaAppearanceProvider('m1').notifier)
        .setDeityImage('other');
    await tester.pumpAndSettle();

    expect(saved, isFalse);
    expect(shown().image, _own);
  });
}

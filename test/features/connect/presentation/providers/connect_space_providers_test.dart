import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_space_providers.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = GroupProfile(id: 'a', title: 'A');
const _b = GroupProfile(id: 'b', title: 'B');

void main() {
  group('resolveConnectSpace', () {
    test('no joined spaces means the landing page', () {
      expect(resolveConnectSpace(joined: const [], rememberedId: 'a'), isNull);
    });

    test('opens the remembered space while it is still joined', () {
      expect(
        resolveConnectSpace(joined: const [_a, _b], rememberedId: 'b'),
        same(_b),
      );
    });

    test('falls back to the first space once the remembered one is left', () {
      expect(
        resolveConnectSpace(joined: const [_a, _b], rememberedId: 'gone'),
        same(_a),
      );
      expect(
        resolveConnectSpace(joined: const [_a, _b], rememberedId: null),
        same(_a),
      );
    });
  });

  group('connectLastSpaceProvider', () {
    test('reads the stored space and remembers a new one', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.connectLastSpaceId: 'a',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(connectLastSpaceProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(connectLastSpaceProvider).spaceId, 'a');
      expect(container.read(connectLastSpaceProvider).loaded, isTrue);

      await container.read(connectLastSpaceProvider.notifier).select('b');
      expect(container.read(connectLastSpaceProvider).spaceId, 'b');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.connectLastSpaceId), 'b');
    });
  });

  group('connectOpenedSpacesProvider', () {
    test('reads the opened spaces and records a new one', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.connectOpenedSpaceIds: ['a'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(connectOpenedSpacesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(connectOpenedSpacesProvider).ids, {'a'});
      expect(container.read(connectOpenedSpacesProvider).loaded, isTrue);

      await container
          .read(connectOpenedSpacesProvider.notifier)
          .markOpened('b');
      expect(container.read(connectOpenedSpacesProvider).ids, {'a', 'b'});
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(StorageKeys.connectOpenedSpaceIds),
        unorderedEquals(['a', 'b']),
      );
    });

    test('keeps a space marked before the stored ids were read', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.connectOpenedSpaceIds: ['a'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(connectOpenedSpacesProvider.notifier)
          .markOpened('b');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(connectOpenedSpacesProvider).ids, {'a', 'b'});
      expect(container.read(connectOpenedSpacesProvider).loaded, isTrue);
    });
  });
}

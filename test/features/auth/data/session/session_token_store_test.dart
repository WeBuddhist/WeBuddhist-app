import 'dart:convert';

import 'package:flutter_pecha/features/auth/data/session/session_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();
  const first = SessionTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
  const second = SessionTokens(
    accessToken: 'access-2',
    refreshToken: 'refresh-2',
  );

  /// A build talking to the given server, prod unless said otherwise.
  SecureSessionTokenStore store({String server = 'production'}) =>
      SecureSessionTokenStore(storage: storage, server: server);

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('nothing stored reads as no session', () async {
    expect(await store().read(), isNull);
  });

  test('a written pair is read back by a new store (next launch)', () async {
    await store().write(first);

    final tokens = await store().read();

    expect(tokens?.accessToken, 'access-1');
    expect(tokens?.refreshToken, 'refresh-1');
  });

  test('the pair is one stored value, so it is replaced whole', () async {
    final tokens = store();
    await tokens.write(first);
    await tokens.write(second);

    // One entry: there is no moment when one account's access token sits
    // beside another's refresh token.
    final all = await storage.readAll();
    expect(all.keys, [SecureSessionTokenStore.sessionKey]);
    expect(jsonDecode(all.values.single), {
      'access_token': 'access-2',
      'refresh_token': 'refresh-2',
      'server': 'production',
    });
  });

  test('clear removes the session for the next launch too', () async {
    final tokens = store();
    await tokens.write(first);

    await tokens.clear();

    expect(await tokens.read(), isNull);
    expect(await store().read(), isNull);
  });

  test('a stored value that is not a complete pair is no session', () async {
    for (final broken in [
      'not json',
      '[]',
      '{"access_token":"a","server":"production"}',
      '{"access_token":"","refresh_token":"r","server":"production"}',
      '{"access_token":"a","refresh_token":7,"server":"production"}',
    ]) {
      FlutterSecureStorage.setMockInitialValues({
        SecureSessionTokenStore.sessionKey: broken,
      });
      expect(await store().read(), isNull, reason: broken);
    }
  });

  test('later reads come from memory, not the keystore', () async {
    final tokens = store();
    await tokens.write(first);

    // Gone from the keystore behind the store's back.
    FlutterSecureStorage.setMockInitialValues({});

    expect((await tokens.read())?.accessToken, 'access-1');
  });

  group('a session names the server that issued it', () {
    test('a build for another server sees no session, and removes it', () async {
      // Signed in on the testing build, then the App Store (prod) build is
      // installed over it. The Keychain keeps the session across that.
      await store(server: 'staging').write(first);

      expect(await store().read(), isNull);
      expect(
        await storage.read(key: SecureSessionTokenStore.sessionKey),
        isNull,
        reason: 'removed, so no later launch has to decide again',
      );
    });

    test('going back does not bring the removed session back', () async {
      await store(server: 'staging').write(first);
      await store().read();

      expect(await store(server: 'staging').read(), isNull);
    });

    test('a session saved before sessions named their server is removed',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureSessionTokenStore.sessionKey: jsonEncode({
          'access_token': 'access-1',
          'refresh_token': 'refresh-1',
        }),
      });

      expect(await store().read(), isNull);
      expect(
        await storage.read(key: SecureSessionTokenStore.sessionKey),
        isNull,
      );
    });

    test('the same server keeps its session', () async {
      await store(server: 'development').write(first);

      final tokens = await store(server: 'development').read();

      expect(tokens?.accessToken, 'access-1');
    });
  });
}

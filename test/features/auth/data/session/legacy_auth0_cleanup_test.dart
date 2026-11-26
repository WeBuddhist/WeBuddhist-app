import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/auth/data/session/legacy_auth0_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// What an Auth0 build left in preferences for a signed-in account.
  const auth0Build = <String, Object>{
    LegacyAuth0CleanupImpl.cachedDomainKey: 'tenant.auth0.com',
    LegacyAuth0CleanupImpl.cachedClientIdKey: 'client-1',
    LegacyAuth0CleanupImpl.cachedAudienceKey: 'https://api.test',
    StorageKeys.currentUserId: 'google-oauth2|1',
    StorageKeys.userData: '{"id":"backend-user-1","email":"tenzin@example.com"}',
    StorageKeys.firstLaunch: true,
  };

  test('removes the Auth0 session an earlier build left', () async {
    SharedPreferences.setMockInitialValues(auth0Build);
    final cleared = <(String, String)>[];
    final cleanup = LegacyAuth0CleanupImpl(
      clearAuth0Credentials: (domain, clientId) async {
        cleared.add((domain, clientId));
      },
    );

    expect(await cleanup.run(), isTrue);

    expect(cleared, [('tenant.auth0.com', 'client-1')]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.currentUserId), isNull);
    expect(prefs.getString(StorageKeys.userData), isNull);
    expect(prefs.getString(LegacyAuth0CleanupImpl.cachedDomainKey), isNull);
    expect(prefs.getString(LegacyAuth0CleanupImpl.cachedClientIdKey), isNull);
    // Unrelated preferences stay.
    expect(prefs.getBool(StorageKeys.firstLaunch), isTrue);
  });

  test('remembers the id local data is keyed by, with the backend id', () async {
    SharedPreferences.setMockInitialValues(auth0Build);
    final cleanup = LegacyAuth0CleanupImpl(
      clearAuth0Credentials: (_, _) async {},
    );

    await cleanup.run();

    // Unsynced mala counts, timer stops and plan actions sit under the Auth0
    // subject. It is kept so the same account can go on using it.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.legacyAuth0UserId), 'google-oauth2|1');
    expect(
      prefs.getString(StorageKeys.legacyAuth0BackendUserId),
      'backend-user-1',
    );
  });

  test('remembers which method the Auth0 login used', () async {
    for (final (subject, method) in [
      ('google-oauth2|1', 'google'),
      ('apple|001.abc', 'apple'),
      ('sms|65f0', 'phone'),
    ]) {
      SharedPreferences.setMockInitialValues({
        ...auth0Build,
        StorageKeys.currentUserId: subject,
      });
      await LegacyAuth0CleanupImpl(
        clearAuth0Credentials: (_, _) async {},
      ).run();

      // Marks that button "Last used" when the person signs in again.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(StorageKeys.lastSignInMethod),
        method,
        reason: subject,
      );
    }
  });

  test('an Auth0 login of a kind the app no longer offers marks nothing', () async {
    SharedPreferences.setMockInitialValues({
      ...auth0Build,
      StorageKeys.currentUserId: 'auth0|1',
    });
    await LegacyAuth0CleanupImpl(clearAuth0Credentials: (_, _) async {}).run();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.lastSignInMethod), isNull);
  });

  test('a profile cached without an id cannot be matched later', () async {
    SharedPreferences.setMockInitialValues({
      ...auth0Build,
      StorageKeys.userData: '{"email":"tenzin@example.com"}',
    });
    final cleanup = LegacyAuth0CleanupImpl(
      clearAuth0Credentials: (_, _) async {},
    );

    expect(await cleanup.run(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.legacyAuth0UserId), isNull);
    expect(prefs.getString(StorageKeys.legacyAuth0BackendUserId), isNull);
  });

  test('runs once: a later sign-in is never touched', () async {
    SharedPreferences.setMockInitialValues(auth0Build);
    var clears = 0;
    final cleanup = LegacyAuth0CleanupImpl(
      clearAuth0Credentials: (_, _) async => clears++,
    );
    await cleanup.run();

    // The person signs in again with Firebase.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.currentUserId, 'backend-user-id');

    expect(await cleanup.run(), isFalse);
    expect(clears, 1);
    expect(prefs.getString(StorageKeys.currentUserId), 'backend-user-id');
  });

  test('a fresh install has nothing to remove', () async {
    SharedPreferences.setMockInitialValues({});
    var clears = 0;
    final cleanup = LegacyAuth0CleanupImpl(
      clearAuth0Credentials: (_, _) async => clears++,
    );

    expect(await cleanup.run(), isFalse);
    expect(clears, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LegacyAuth0CleanupImpl.doneKey), isTrue);
  });

  test('a guest on an Auth0 build stays a guest', () async {
    SharedPreferences.setMockInitialValues({
      LegacyAuth0CleanupImpl.cachedDomainKey: 'tenant.auth0.com',
      LegacyAuth0CleanupImpl.cachedClientIdKey: 'client-1',
      'is_guest_mode': true,
    });
    final cleanup = LegacyAuth0CleanupImpl(
      clearAuth0Credentials: (_, _) async {},
    );

    await cleanup.run();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('is_guest_mode'), isTrue);
  });

  test('a failed clear is tried again on the next launch', () async {
    SharedPreferences.setMockInitialValues(auth0Build);
    var attempts = 0;
    final cleanup = LegacyAuth0CleanupImpl(
      clearAuth0Credentials: (_, _) async {
        attempts++;
        if (attempts == 1) throw StateError('keychain unavailable');
      },
    );

    expect(await cleanup.run(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LegacyAuth0CleanupImpl.doneKey), isNull);
    // Nothing half-removed: the account markers wait for the retry.
    expect(prefs.getString(StorageKeys.currentUserId), 'google-oauth2|1');

    expect(await cleanup.run(), isTrue);
    expect(attempts, 2);
    expect(prefs.getString(StorageKeys.currentUserId), isNull);
  });
}

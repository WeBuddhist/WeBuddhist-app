import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/network/connectivity_service.dart'
    show connectivityNotifierProvider;
import 'package:flutter_pecha/core/storage/preferences_service.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SignInMethod { google, apple, phone }

/// How the signed-in account logged in, shown in Settings so people know
/// which account they are signing out of.
class SignInAccount extends Equatable {
  const SignInAccount({required this.method, required this.identifier});

  /// null when the method was not recorded at sign-in.
  final SignInMethod? method;

  /// Email for Google and Apple, phone number for phone sign-in.
  final String identifier;

  @override
  List<Object?> get props => [method, identifier];
}

/// [stored] is what `AuthService` saved under [StorageKeys.signInMethod] at
/// sign-in: `google`, `apple` or `phone`. The backend's tokens do not name
/// the provider.
SignInMethod? signInMethodFromStored(String? stored) => switch (stored) {
  'google' => SignInMethod.google,
  'apple' => SignInMethod.apple,
  'phone' => SignInMethod.phone,
  _ => null,
};

/// Builds the account from the stored sign-in [method], the profile [email],
/// and the access token [claims] (only needed when the profile has no
/// identifier).
///
/// The backend puts the account's `email` and `phone_number` in its access
/// token. An account can hold both (a phone linked to a Google account), so
/// the one that matches [method] is shown; with no recorded method, whichever
/// exists.
SignInAccount? resolveSignInAccount({
  required SignInMethod? method,
  String? email,
  Map<String, dynamic>? claims,
}) {
  String? text(Object? value) {
    final trimmed = value is String ? value.trim() : '';
    return trimmed.isEmpty ? null : trimmed;
  }

  final accountEmail = text(email) ?? text(claims?['email']);
  final phone = text(claims?['phone_number']);

  final identifier = switch (method) {
    SignInMethod.phone => phone,
    SignInMethod.google || SignInMethod.apple => accountEmail,
    null => accountEmail ?? phone,
  };

  if (identifier == null) return null;
  return SignInAccount(method: method, identifier: identifier);
}

/// Decodes the payload of a JWT, or null when it is not one.
Map<String, dynamic>? decodeJwtClaims(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = base64Url.decode(base64Url.normalize(parts[1]));
    return jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// The signed-in account's sign-in method and email or phone number.
///
/// Google and Apple accounts resolve from the profile; the access token is
/// read only when the profile has no identifier, as for phone sign-in.
final signInAccountProvider = FutureProvider.autoDispose<SignInAccount?>((
  ref,
) async {
  final email = ref.watch(userProvider.select((s) => s.user?.email));
  final method = signInMethodFromStored(
    SharedPreferencesService.instance.getSync<String>(
      StorageKeys.signInMethod,
    ),
  );

  if (method != SignInMethod.phone) {
    final fromProfile = resolveSignInAccount(method: method, email: email);
    if (fromProfile != null) return fromProfile;
  }

  final credentials = await ref.read(authRepositoryProvider).getCredentials();
  final failure = credentials.fold((f) => f, (_) => null);
  if (failure is NetworkFailure) {
    // Offline token renewal is temporary: look again once back online
    // rather than leaving the row hidden while Settings stays open.
    ref.listen<bool>(connectivityNotifierProvider, (wasOnline, isOnline) {
      if (isOnline && wasOnline != true) ref.invalidateSelf();
    });
    return null;
  }
  final accessToken = credentials.fold((_) => null, (c) => c.accessToken);
  if (accessToken == null || accessToken.isEmpty) return null;

  return resolveSignInAccount(
    method: method,
    email: email,
    claims: decodeJwtClaims(accessToken),
  );
});

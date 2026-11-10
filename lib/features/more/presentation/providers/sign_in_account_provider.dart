import 'dart:convert';

import 'package:equatable/equatable.dart';
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

  /// null when the Auth0 connection is not one the app offers.
  final SignInMethod? method;

  /// Email for Google and Apple, phone number for phone sign-in.
  final String identifier;

  @override
  List<Object?> get props => [method, identifier];
}

/// [userId] is the Auth0 `sub`, e.g. `google-oauth2|…`, `apple|…`, `sms|…`.
SignInMethod? signInMethodFromUserId(String? userId) {
  if (userId == null) return null;
  if (userId.startsWith('google-oauth2|')) return SignInMethod.google;
  if (userId.startsWith('apple|')) return SignInMethod.apple;
  if (userId.startsWith('sms|')) return SignInMethod.phone;
  return null;
}

final _phonePattern = RegExp(r'^\+?[0-9][0-9 ()\-]{5,}$');

/// Builds the account from the Auth0 [userId], the profile [email], and the
/// ID token [claims] (only needed when the profile has no identifier).
///
/// Auth0 puts the phone number in `phone_number` when the `phone` scope is
/// granted, and in `name` for passwordless SMS accounts otherwise.
SignInAccount? resolveSignInAccount({
  required String? userId,
  String? email,
  Map<String, dynamic>? claims,
}) {
  final method = signInMethodFromUserId(userId ?? claims?['sub'] as String?);

  String? identifier;
  if (method == SignInMethod.phone) {
    final phone = (claims?['phone_number'] as String?)?.trim();
    final name = (claims?['name'] as String?)?.trim();
    identifier =
        (phone != null && phone.isNotEmpty)
            ? phone
            : (name != null && _phonePattern.hasMatch(name))
            ? name
            : null;
  } else {
    final profileEmail = email?.trim();
    identifier =
        (profileEmail != null && profileEmail.isNotEmpty)
            ? profileEmail
            : (claims?['email'] as String?)?.trim();
  }

  if (identifier == null || identifier.isEmpty) return null;
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
/// Google and Apple accounts resolve from the profile; the stored ID token is
/// read only when the profile has no identifier, as for phone sign-in.
final signInAccountProvider = FutureProvider.autoDispose<SignInAccount?>((
  ref,
) async {
  final email = ref.watch(userProvider.select((s) => s.user?.email));
  final userId = SharedPreferencesService.instance.getSync<String>(
    StorageKeys.currentUserId,
  );

  final fromProfile = resolveSignInAccount(userId: userId, email: email);
  if (fromProfile != null) return fromProfile;

  final credentials = await ref.read(authRepositoryProvider).getCredentials();
  final idToken = credentials.fold((_) => null, (c) => c.idToken);
  if (idToken == null || idToken.isEmpty) return null;

  return resolveSignInAccount(
    userId: userId,
    email: email,
    claims: decodeJwtClaims(idToken),
  );
});

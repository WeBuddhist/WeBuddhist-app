import 'package:flutter_pecha/core/storage/preferences_service.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sign-in method last used on this phone (`google`, `apple` or `phone`),
/// or null when none has been yet. See [StorageKeys.lastSignInMethod].
///
/// Read again whenever someone signs in or out, since that is when it changes.
final lastSignInMethodProvider = Provider.autoDispose<String?>((ref) {
  ref.watch(authProvider.select((s) => s.isLoggedIn && !s.isGuest));
  return SharedPreferencesService.instance.getSync<String>(
    StorageKeys.lastSignInMethod,
  );
});

/// Whether the button for [connection] (`google`, `apple`, or
/// [AuthNotifier.phoneConnection]) is the one last used on this phone.
bool isLastUsedConnection(String? lastSignInMethod, String connection) {
  if (lastSignInMethod == null) return false;
  final method =
      connection == AuthNotifier.phoneConnection ? 'phone' : connection;
  return method == lastSignInMethod;
}

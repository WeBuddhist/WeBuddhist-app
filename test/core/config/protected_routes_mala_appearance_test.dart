import 'package:flutter_pecha/core/config/api_config.dart';
import 'package:flutter_pecha/core/config/protected_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mala appearance routes always send the token', () {
    // A space's own mantra 404s without it, and the PATCH is per user.
    for (final path in [
      '${ApiConfig.mantrasV2Path}/m1/images',
      ApiConfig.malaSkinsV2Path,
      '${ApiConfig.userMantrasV2Path}/m1/appearance',
      // The catalogue: without the token every last_used_at is null.
      ApiConfig.accumulationsV2Path,
    ]) {
      expect(ProtectedRoutes.isProtected(path), isTrue, reason: path);
    }
  });
}

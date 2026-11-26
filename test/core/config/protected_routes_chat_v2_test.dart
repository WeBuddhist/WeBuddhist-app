import 'package:flutter_pecha/core/config/api_config.dart';
import 'package:flutter_pecha/core/config/protected_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 chat routes send the token', () {
    // The inbox and mark-read are per member; without it they answer 403.
    for (final path in [
      '${ApiConfig.chatV2Path}/rooms',
      '${ApiConfig.chatV2Path}/rooms/r1/read',
    ]) {
      expect(ProtectedRoutes.isProtected(path), isTrue, reason: path);
    }
  });
}

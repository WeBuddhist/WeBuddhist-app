import 'package:flutter_pecha/features/library/domain/library_license_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only CC0 and public domain texts are shown', () {
    expect(LibraryLicensePolicy.isAllowed('cc0'), isTrue);
    expect(LibraryLicensePolicy.isAllowed('public'), isTrue);
    expect(LibraryLicensePolicy.isAllowed(' CC0 '), isTrue);
    for (final license in [
      'cc-by',
      'cc-by-sa',
      'cc-by-nd',
      'cc-by-nc',
      'cc-by-nc-sa',
      'cc-by-nc-nd',
      'copyrighted',
      'unknown',
      '',
      null,
    ]) {
      expect(LibraryLicensePolicy.isAllowed(license), isFalse, reason: license);
    }
  });
}

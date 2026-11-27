/// Which library texts the app may show, by their `license` value.
///
/// Only texts free for any use are shown: CC0 and the Public Domain Mark.
/// Everything else, `unknown` and a missing license included, is treated as
/// copyrighted and hidden.
abstract final class LibraryLicensePolicy {
  /// Values sent as the library's `license` filter, in API spelling.
  static const List<String> allowed = ['cc0', 'public'];

  static final Set<String> _allowed = allowed.toSet();

  static bool isAllowed(String? license) {
    if (license == null) return false;
    return _allowed.contains(license.trim().toLowerCase());
  }
}

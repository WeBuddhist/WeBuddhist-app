/// The name the app shows for a user: the display name they picked in Edit
/// profile, then their full name (first and last, for a user who has not
/// picked one), then their username, then [fallback]. Each is trimmed; blank
/// ones are skipped.
///
/// The one place this order is decided, so group members, accumulator rows,
/// event participants, reports, comments and chat never disagree.
String visibleUserName({
  String? displayName,
  String? fullname,
  String? username,
  String fallback = '',
}) {
  for (final candidate in [displayName, fullname, username]) {
    final trimmed = candidate?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

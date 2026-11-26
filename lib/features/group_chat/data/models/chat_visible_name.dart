/// The name to show for a person in a chat payload: the display name they
/// picked in Edit profile ([displayName], the payload's `display_name` or
/// `*_display_name`), then [name], which the backend builds from their first
/// and last name. Null when the payload has neither.
///
/// Resolved where the payload is read, so every screen that shows the
/// person's name agrees without choosing again.
String? chatVisibleName(Object? displayName, Object? name) {
  final picked = displayName is String ? displayName.trim() : '';
  if (picked.isNotEmpty) return picked;
  return name is String ? name : null;
}

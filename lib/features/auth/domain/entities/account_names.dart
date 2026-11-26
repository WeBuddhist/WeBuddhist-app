/// The first and last name a new account is created with.
///
/// The backend will not create an account without both. A provider does not
/// always share them: phone sign-in shares none, Apple can withhold the name,
/// and a Google account can have a single name. Nobody is asked to type one
/// during sign-in; the gap is filled here instead.
class AccountNames {
  const AccountNames({required this.first, required this.last});

  /// What an account is called until its owner says otherwise. Phone accounts
  /// start with it, and the onboarding step that asks "What should we call
  /// you?" replaces it (see [fromDisplayName]).
  static const AccountNames placeholder = AccountNames(
    first: 'WeBuddhist',
    last: 'User',
  );

  final String first;
  final String last;

  /// [first] and [last] with whatever is missing filled in: a single name
  /// stands for both, and no name at all becomes the [placeholder].
  factory AccountNames.complete(String? first, String? last) {
    final given = _tidy(first);
    final family = _tidy(last);
    if (given == null && family == null) return placeholder;
    return AccountNames(first: given ?? family!, last: family ?? given!);
  }

  /// The names for a display name someone typed: "Pema Lhamo Dolkar" is first
  /// "Pema", last "Lhamo Dolkar". Null when there is nothing to go on.
  static AccountNames? fromDisplayName(String? displayName) {
    final name = _tidy(displayName);
    if (name == null) return null;
    final space = name.indexOf(' ');
    if (space == -1) return AccountNames.complete(name, null);
    return AccountNames.complete(
      name.substring(0, space),
      name.substring(space + 1),
    );
  }

  /// Whether [first] and [last] are still the [placeholder], i.e. the owner
  /// has not given a name yet.
  static bool isPlaceholder(String? first, String? last) =>
      _tidy(first) == placeholder.first && _tidy(last) == placeholder.last;

  static String? _tidy(String? value) {
    final tidy = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    return tidy.isEmpty ? null : tidy;
  }

  @override
  bool operator ==(Object other) =>
      other is AccountNames && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'AccountNames($first, $last)';
}

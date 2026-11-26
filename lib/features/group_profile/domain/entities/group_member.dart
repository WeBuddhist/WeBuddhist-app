import 'package:flutter_pecha/features/group_profile/domain/entities/group_member_role.dart';
import 'package:flutter_pecha/shared/domain/visible_name.dart';

class GroupMember {
  final String userId;
  final String username;
  final String fullname;

  /// The name the user picked in Edit profile (`display_name`).
  final String? userDisplayName;
  final String? avatarUrl;

  /// Membership role from the members list. See [GroupMemberRole].
  final String? role;

  const GroupMember({
    this.userId = '',
    required this.username,
    required this.fullname,
    this.userDisplayName,
    this.avatarUrl,
    this.role,
  });

  /// Name shown in the UI: the display name, then the full name for
  /// responses without one, then the username.
  String get displayName => visibleUserName(
    displayName: userDisplayName,
    fullname: fullname,
    username: username,
  );

  /// `OWNER` or `ADMIN`. Both get a role badge and are never removable.
  bool get isAdmin => GroupMemberRole.isAdminTier(role);

  bool get isOwner => GroupMemberRole.isOwner(role);

  /// An admin can remove a regular member once the list includes their id.
  bool get canBeRemovedByAdmin => userId.trim().isNotEmpty && !isAdmin;
}

import 'package:flutter_pecha/features/group_profile/domain/entities/group_member.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_members_page.dart';

class GroupMemberModel {
  final String userId;
  final String username;
  final String fullname;
  final String? displayName;
  final String? avatarUrl;
  final String? role;

  GroupMemberModel({
    this.userId = '',
    required this.username,
    required this.fullname,
    this.displayName,
    this.avatarUrl,
    this.role,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'] as String?;
    final role = json['role'] as String?;
    final displayName = json['display_name'] as String?;
    return GroupMemberModel(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullname: json['fullname'] as String? ?? '',
      displayName: displayName != null && displayName.trim().isNotEmpty
          ? displayName.trim()
          : null,
      avatarUrl: avatar != null && avatar.trim().isNotEmpty ? avatar : null,
      role: role != null && role.trim().isNotEmpty ? role.trim() : null,
    );
  }

  GroupMember toEntity() {
    return GroupMember(
      userId: userId,
      username: username,
      fullname: fullname,
      userDisplayName: displayName,
      avatarUrl: avatarUrl,
      role: role,
    );
  }
}

class GroupMembersPageModel {
  final List<GroupMemberModel> members;
  final int skip;
  final int limit;
  final int totalMembers;

  GroupMembersPageModel({
    required this.members,
    required this.skip,
    required this.limit,
    required this.totalMembers,
  });

  factory GroupMembersPageModel.fromJson(Map<String, dynamic> json) {
    return GroupMembersPageModel(
      members:
          (json['list'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(GroupMemberModel.fromJson)
              .toList() ??
          const [],
      skip: (json['skip'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
    );
  }

  GroupMembersPage toEntity() {
    return GroupMembersPage(
      members: members.map((member) => member.toEntity()).toList(),
      skip: skip,
      limit: limit,
      totalMembers: totalMembers,
    );
  }
}

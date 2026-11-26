import 'package:flutter_pecha/features/group_profile/data/models/group_member_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses user id and admin role', () {
    final member =
        GroupMemberModel.fromJson({
          'user_id': 'c9957b3d-43ea-4f37-bd60-a7dd37a10c6a',
          'username': 'pema',
          'fullname': 'Pema Chödrön',
          'avatar_url': 'https://example.com/a.webp',
          'role': 'admin',
        }).toEntity();

    expect(member.userId, 'c9957b3d-43ea-4f37-bd60-a7dd37a10c6a');
    expect(member.username, 'pema');
    expect(member.isAdmin, isTrue);
    expect(member.isOwner, isFalse);
    expect(member.canBeRemovedByAdmin, isFalse);
  });

  test('the group owner is admin-tier and cannot be removed', () {
    final member =
        GroupMemberModel.fromJson({
          'user_id': 'owner-1',
          'username': 'rinpoche',
          'fullname': 'Rinpoche',
          'role': 'OWNER',
        }).toEntity();

    expect(member.isOwner, isTrue);
    expect(member.isAdmin, isTrue);
    expect(member.canBeRemovedByAdmin, isFalse);
  });

  test('a member without id or role cannot be removed yet', () {
    final member =
        GroupMemberModel.fromJson({
          'username': 'ani',
          'fullname': 'Ani Tenzin',
          'avatar_url': '',
          'role': null,
        }).toEntity();

    expect(member.userId, isEmpty);
    expect(member.avatarUrl, isNull);
    expect(member.isAdmin, isFalse);
    expect(member.canBeRemovedByAdmin, isFalse);
  });

  test('a regular member with an id can be removed', () {
    final member =
        GroupMemberModel.fromJson({
          'user_id': 'u1',
          'username': 'dipa',
          'fullname': 'Dipa Ma',
          'role': 'MEMBER',
        }).toEntity();

    expect(member.canBeRemovedByAdmin, isTrue);
  });

  group('displayName', () {
    test('prefers display_name over fullname', () {
      final member =
          GroupMemberModel.fromJson({
            'username': 'tenzin',
            'fullname': 'Tenzin Dorje',
            'display_name': '  tenz  ',
          }).toEntity();

      expect(member.userDisplayName, 'tenz');
      expect(member.displayName, 'tenz');
    });

    test('falls back to fullname when display_name is missing or blank', () {
      final missing =
          GroupMemberModel.fromJson({
            'username': 'tenzin',
            'fullname': 'Tenzin Dorje',
          }).toEntity();
      final blank =
          GroupMemberModel.fromJson({
            'username': 'tenzin',
            'fullname': 'Tenzin Dorje',
            'display_name': '   ',
          }).toEntity();

      expect(missing.userDisplayName, isNull);
      expect(missing.displayName, 'Tenzin Dorje');
      expect(blank.userDisplayName, isNull);
      expect(blank.displayName, 'Tenzin Dorje');
    });

    test('falls back to username when both names are empty', () {
      final member =
          GroupMemberModel.fromJson({
            'username': 'tenzin',
            'fullname': '',
            'display_name': null,
          }).toEntity();

      expect(member.displayName, 'tenzin');
    });
  });
}

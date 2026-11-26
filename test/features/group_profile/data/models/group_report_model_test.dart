import 'package:flutter_pecha/features/group_profile/data/models/group_report_model.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_report.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _reportJson({
  required String id,
  required String kind,
  String? messageId,
  String? commentId,
  String? postId,
}) {
  return {
    'id': id,
    'kind': kind,
    'reason': 'OTHER',
    'description': 'Off-topic or disruptive',
    'source': 'MANUAL',
    'content_text': 'yes',
    'post_id': postId,
    'comment_id': commentId,
    'message_id': messageId,
    'room_id': null,
    'room_name': 'The Sacred Circle of Trust',
    'reporter': {
      'id': 'f44c',
      'username': 'tenzin_dhakar105',
      'firstname': 'Tenzin',
      'lastname': 'Dhakar105',
    },
    'reported_user': {
      'id': 'fb04',
      'username': 'chris',
      'firstname': '',
      'lastname': '',
    },
    'created_at': '2026-10-06T06:10:32.585648+00:00',
    'resolved_at': null,
  };
}

void main() {
  test('parses a page and skips reports of an unknown kind', () {
    final page =
        GroupReportsPageModel.fromJson({
          'reports': [
            _reportJson(id: 'r1', kind: 'CHAT_MESSAGE', messageId: 'm1'),
            _reportJson(id: 'r2', kind: 'SOMETHING_NEW'),
          ],
          'skip': 0,
          'limit': 20,
          'total': 2,
        }).toEntity();

    expect(page.reports, hasLength(1));
    expect(page.total, 2);
    final report = page.reports.single;
    expect(report.kind, GroupReportKind.chatMessage);
    expect(report.messageId, 'm1');
    expect(report.postId, isNull);
    expect(report.description, 'Off-topic or disruptive');
    expect(report.reporter?.displayName, 'Tenzin Dhakar105');
    expect(report.reportedUser?.displayName, 'chris');
    expect(report.createdAt, isNotNull);
    expect(report.resolvedAt, isNull);
  });

  test('groups reports by the content they target, newest item first', () {
    GroupReport parse(Map<String, dynamic> json) =>
        GroupReportModel.fromJson(json)!.toEntity();

    final items = groupReportsByTarget([
      parse(_reportJson(id: 'r1', kind: 'COMMENT', commentId: 'c1')),
      parse(_reportJson(id: 'r2', kind: 'CHAT_MESSAGE', messageId: 'm1')),
      parse(_reportJson(id: 'r3', kind: 'COMMENT', commentId: 'c1')),
      parse(_reportJson(id: 'r4', kind: 'POST', postId: 'p1')),
    ]);

    expect(items.map((item) => item.targetId), ['c1', 'm1', 'p1']);
    expect(items.first.reports.map((report) => report.id), ['r1', 'r3']);
    expect(items.first.latest.id, 'r1');
  });

  group('GroupReportUser.displayName', () {
    test('prefers the display name over first and last name', () {
      const user = GroupReportUser(
        id: 'u1',
        username: 'tenzin',
        firstname: 'Tenzin',
        lastname: 'Dorje',
        userDisplayName: '  tenz  ',
      );

      expect(user.displayName, 'tenz');
    });

    test('falls back to first and last name when it is blank', () {
      const user = GroupReportUser(
        id: 'u1',
        username: 'tenzin',
        firstname: 'Tenzin',
        lastname: 'Dorje',
        userDisplayName: '  ',
      );

      expect(user.displayName, 'Tenzin Dorje');
    });

    test('falls back to the username when no name is set', () {
      const user = GroupReportUser(id: 'u1', username: 'tenzin');

      expect(user.displayName, 'tenzin');
    });
  });

  test('reporter fromJson forwards display_name', () {
    final json = _reportJson(id: 'r1', kind: 'POST', postId: 'p1');
    (json['reporter'] as Map<String, dynamic>)['display_name'] = 'Tenz';

    final report = GroupReportModel.fromJson(json)!.toEntity();

    expect(report.reporter?.userDisplayName, 'Tenz');
    expect(report.reporter?.displayName, 'Tenz');
    expect(report.reportedUser?.userDisplayName, isNull);
  });
}

import 'package:flutter_pecha/features/group_profile/data/models/group_accumulator_model.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Object? mantra, Object? malaImage}) => {
  'id': 'acc-1',
  'preset_accumulator_id': null,
  'text_id': null,
  'mantra_id': 'mantra-1',
  'group_id': 'group-1',
  'title': 'Space accumulation',
  if (mantra != null) 'mantra': mantra,
  if (malaImage != null) 'mala_image': malaImage,
};

const _mantraJson = {
  'id': 'mantra-1',
  'mantra': 'ཨོཾ་ཨཀྵོ་བྷྱ་ཧཱུྃ།',
  'title': 'Buddha Akshobhya Mantra',
  'pronunciation': 'Om Akshobhya Hum',
  'audio_url': null,
  'mala_image_id': 'img-1',
  'mala_image_url': 'https://example.com/default.webp',
  'deity_image': {
    'thumbnail': 'https://example.com/t.webp',
    'medium': 'https://example.com/m.webp',
    'original': 'https://example.com/o.webp',
  },
};

void main() {
  group('GroupAccumulatorModel.fromJson', () {
    test('parses the space mantra and the resolved mala skin', () {
      final detail =
          GroupAccumulatorModel.fromJson(
            _json(
              mantra: _mantraJson,
              malaImage: {'id': 'img-2', 'url': 'https://example.com/skin.webp'},
            ),
          ).toDetailEntity();

      expect(detail.presetAccumulatorId, isEmpty);
      expect(detail.mantra?.id, 'mantra-1');
      expect(detail.mantra?.text, 'ཨོཾ་ཨཀྵོ་བྷྱ་ཧཱུྃ།');
      expect(detail.mantra?.title, 'Buddha Akshobhya Mantra');
      expect(detail.mantra?.pronunciation, 'Om Akshobhya Hum');
      expect(detail.mantra?.beadImageUrl, 'https://example.com/default.webp');
      expect(detail.mantra?.deityImage, isNotNull);
      expect(detail.malaImageUrl, 'https://example.com/skin.webp');
      expect(detail.hasMantraContent, isTrue);
    });

    test('list entity carries the mantra too', () {
      final item = GroupAccumulatorModel.fromJson(
        _json(mantra: _mantraJson),
      ).toEntity();

      expect(item.mantra?.pronunciation, 'Om Akshobhya Hum');
    });

    test('a missing or null mantra gives null', () {
      final missing = GroupAccumulatorModel.fromJson(_json()).toDetailEntity();
      final nulled =
          GroupAccumulatorModel.fromJson({
            ..._json(),
            'mantra': null,
            'mala_image': null,
          }).toDetailEntity();

      expect(missing.mantra, isNull);
      expect(missing.malaImageUrl, isNull);
      expect(nulled.mantra, isNull);
      expect(nulled.malaImageUrl, isNull);
    });

    test('an empty mala skin url gives null', () {
      final detail =
          GroupAccumulatorModel.fromJson(
            _json(malaImage: {'id': 'img-2', 'url': ''}),
          ).toDetailEntity();

      expect(detail.malaImageUrl, isNull);
    });
  });

  group('GroupAccumulatorMember.displayName', () {
    test('prefers the display name over the full name', () {
      const member = GroupAccumulatorMember(
        userId: 'u1',
        username: 'tenzin',
        fullname: 'Tenzin Dorje',
        userDisplayName: '  tenz  ',
      );

      expect(member.displayName, 'tenz');
    });

    test('falls back to the full name, then the username', () {
      const withFullname = GroupAccumulatorMember(
        userId: 'u1',
        username: 'tenzin',
        fullname: 'Tenzin Dorje',
        userDisplayName: '  ',
      );
      const withUsername = GroupAccumulatorMember(
        userId: 'u2',
        username: 'tenzin',
        fullname: '',
      );

      expect(withFullname.displayName, 'Tenzin Dorje');
      expect(withUsername.displayName, 'tenzin');
    });
  });

  group('GroupAccumulatorUserContribution.displayName', () {
    test('prefers the display name over the full name', () {
      const contribution = GroupAccumulatorUserContribution(
        username: 'tenzin',
        fullname: 'Tenzin Dorje',
        userDisplayName: 'tenz',
      );

      expect(contribution.displayName, 'tenz');
    });

    test('falls back to the full name, then the username', () {
      const withFullname = GroupAccumulatorUserContribution(
        username: 'tenzin',
        fullname: 'Tenzin Dorje',
      );
      const withUsername = GroupAccumulatorUserContribution(
        username: 'tenzin',
      );

      expect(withFullname.displayName, 'Tenzin Dorje');
      expect(withUsername.displayName, 'tenzin');
    });
  });

  group('display_name from the API', () {
    test('member fromJson forwards display_name', () {
      final member =
          GroupAccumulatorMemberModel.fromJson({
            'user_id': 'u1',
            'username': 'tenzin',
            'fullname': 'Tenzin Dorje',
            'display_name': 'Tenz',
          }).toEntity();

      expect(member.userDisplayName, 'Tenz');
      expect(member.displayName, 'Tenz');
    });

    test('member without display_name falls back to fullname', () {
      final member =
          GroupAccumulatorMemberModel.fromJson({
            'user_id': 'u1',
            'username': 'tenzin',
            'fullname': 'Tenzin Dorje',
          }).toEntity();

      expect(member.userDisplayName, isNull);
      expect(member.displayName, 'Tenzin Dorje');
    });

    test('contribution fromJson forwards display_name', () {
      final contribution =
          GroupAccumulatorUserContributionModel.fromJson({
            'username': 'tenzin',
            'fullname': 'Tenzin Dorje',
            'display_name': 'Tenz',
          }).toEntity();

      expect(contribution.userDisplayName, 'Tenz');
      expect(contribution.displayName, 'Tenz');
    });
  });
}

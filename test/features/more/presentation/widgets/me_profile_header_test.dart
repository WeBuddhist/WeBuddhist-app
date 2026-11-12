import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/features/auth/domain/entities/user.dart';
import 'package:flutter_pecha/features/more/presentation/widgets/me_profile_header.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpHeader(
  WidgetTester tester,
  User user, {
  VoidCallback? onEditProfile,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MeProfileHeader(user: user, onEditProfile: onEditProfile),
      ),
    ),
  );
}

void main() {
  testWidgets('does not show the email; it lives in Settings', (tester) async {
    await _pumpHeader(
      tester,
      const User(
        id: 'me',
        displayName: 'Tenzin Dolma',
        username: 'tenzin',
        email: 'tenzin@example.com',
      ),
    );

    expect(find.text('tenzin@example.com'), findsNothing);
  });

  testWidgets('shows the display name and bio, not the username', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      const User(
        id: 'me',
        displayName: 'Tenzin Dolma',
        username: 'tenzin',
        aboutMe: 'Practising compassion daily',
      ),
    );

    expect(find.text('Tenzin Dolma'), findsOneWidget);
    expect(find.text('Practising compassion daily'), findsOneWidget);
    expect(find.text('tenzin'), findsNothing);
  });

  testWidgets('falls back to first and last name without a display name', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      const User(id: 'me', firstName: 'Tenzin', lastName: 'Dolma'),
    );

    expect(find.text('Tenzin Dolma'), findsOneWidget);
  });

  testWidgets('shows only the name without a bio', (tester) async {
    await _pumpHeader(
      tester,
      const User(id: 'me', displayName: 'Tenzin Dolma', username: 'tenzin'),
    );

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('tapping the pencil calls onEditProfile', (tester) async {
    var taps = 0;
    await _pumpHeader(
      tester,
      const User(id: 'me', displayName: 'Tenzin Dolma'),
      onEditProfile: () => taps++,
    );

    await tester.tap(find.byIcon(AppAssets.pencilSimple));

    expect(taps, 1);
  });

  testWidgets('hides the pencil without onEditProfile', (tester) async {
    await _pumpHeader(tester, const User(id: 'me', displayName: 'Tenzin'));

    expect(find.byIcon(AppAssets.pencilSimple), findsNothing);
  });
}

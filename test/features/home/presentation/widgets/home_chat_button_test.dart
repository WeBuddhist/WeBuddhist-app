import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_unread_dot.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/home_chat_button.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool hasUnread,
  VoidCallback? onPressed,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: HomeChatIconButton(
            hasUnread: hasUnread,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a dot only while a room is unread', (tester) async {
    await _pump(tester, hasUnread: true);
    expect(find.byType(ConnectUnreadDot), findsOneWidget);

    await _pump(tester, hasUnread: false);
    expect(find.byType(ConnectUnreadDot), findsNothing);
  });

  testWidgets('is labelled Chats and opens on tap', (tester) async {
    var taps = 0;
    await _pump(tester, hasUnread: false, onPressed: () => taps++);
    expect(find.byTooltip('Chats'), findsOneWidget);

    await tester.tap(find.byType(HomeChatIconButton));
    expect(taps, 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/shared/widgets/appBottomNavBar/app_bottom_nav_item.dart';
import 'package:flutter_test/flutter_test.dart';

AppBottomBarItemModel<int> _item({bool hasBadge = false}) {
  return AppBottomBarItemModel(
    type: 2,
    label: 'Connect',
    selectedWidget: null,
    selectedIconData: Icons.people,
    unSelectedIconData: Icons.people_outline,
    hasBadge: hasBadge,
  );
}

/// The red dot is the only circle filled with the unread colour.
Finder _dot() => find.byWidgetPredicate((widget) {
  if (widget is! Container) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.shape == BoxShape.circle &&
      decoration.color == AppColors.unreadBadge;
});

Future<void> _pump(WidgetTester tester, AppBottomBarItemModel<int> item) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppBottomNavItem<int>(model: item, selectedType: 0),
      ),
    ),
  );
}

void main() {
  testWidgets('a badged tab shows the unread dot', (tester) async {
    await _pump(tester, _item(hasBadge: true));

    expect(_dot(), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('an unbadged tab has no dot', (tester) async {
    await _pump(tester, _item());

    expect(_dot(), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_filter_pills.dart';

/// Which spaces a See-all screen lists (Plans, Space accumulations).
enum SpaceFilter {
  /// The joined spaces and the rest (on Plans, the catalog too).
  all,

  /// Spaces the user joined.
  mySpaces,

  /// Spaces the user has not joined.
  otherSpaces;

  /// The pills a user gets: a guest has no spaces of their own, so no My
  /// spaces pill.
  static List<SpaceFilter> available({required bool isGuest}) => [
    all,
    if (!isGuest) mySpaces,
    otherSpaces,
  ];
}

/// All / My spaces / Other spaces, lined up with a 16pt list.
class SpaceFilterPills extends StatelessWidget {
  const SpaceFilterPills({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<SpaceFilter> filters;
  final SpaceFilter selected;
  final ValueChanged<SpaceFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ChantFilterPills(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      labels: [
        for (final f in filters)
          switch (f) {
            SpaceFilter.all => l10n.chants_filter_all,
            SpaceFilter.mySpaces => l10n.my_groups,
            SpaceFilter.otherSpaces => l10n.chants_other_spaces,
          },
      ],
      selectedIndex: filters.indexOf(selected),
      onSelected: (i) => onSelected(filters[i]),
    );
  }
}

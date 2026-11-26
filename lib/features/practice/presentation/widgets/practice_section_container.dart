import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

class PracticeSectionContainer extends StatelessWidget {
  const PracticeSectionContainer({
    super.key,
    required this.title,
    required this.child,
    this.seeAllLabel,
    this.onSeeAll,
    this.isSubsection = false,
  });

  final String title;
  final Widget child;
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;

  /// A row inside a group such as "From your spaces": a smaller title
  /// under the group's heading, and less space above.
  final bool isSubsection;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(top: isSubsection ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSubsection ? 16 : 18,
                      fontWeight:
                          isSubsection ? FontWeight.w600 : FontWeight.w700,
                    ),
                  ),
                ),
                if (seeAllLabel != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text(
                      seeAllLabel!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: isSubsection ? 10 : 12),
          child,
        ],
      ),
    );
  }
}

/// Heading over a group of Practice tab rows, such as "Discover more".
class PracticeGroupHeading extends StatelessWidget {
  const PracticeGroupHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }
}

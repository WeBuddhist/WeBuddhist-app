import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

/// The warm tones of the personal chant book designs: the Add to chant book
/// and New chant book sheets, and the chant book page.
abstract final class ChantBookColors {
  /// Sheet body.
  static Color sheet(bool isDark) =>
      isDark ? AppColors.cardBackgroundDark : const Color(0xFFFFF8EC);

  /// Sheet header band, chips and the add tiles.
  static Color tint(bool isDark) =>
      isDark ? AppColors.surfaceVariantDark : const Color(0xFFFDF0D9);

  /// Top of the chant book page's gradient.
  static Color pageTop(bool isDark) =>
      isDark ? AppColors.scaffoldBackgroundDark : const Color(0xFFFCEACB);

  /// Bottom of the chant book page's gradient, and its background below.
  static Color pageBottom(bool isDark) =>
      isDark ? AppColors.scaffoldBackgroundDark : AppColors.surfaceLight;

  /// Cover tile with no image.
  static Color coverPlaceholder(bool isDark) =>
      isDark ? AppColors.grey800 : const Color(0xFFE6E4DF);

  /// The chant book name while it isn't being edited.
  static Color nameFill(bool isDark) =>
      isDark ? AppColors.surfaceVariantDark : const Color(0xFFF0EFED);

  static Color secondaryText(bool isDark) =>
      isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
}

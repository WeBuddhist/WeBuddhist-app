import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/share_analytics.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/deep_linking/deep_link_url_builder.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/services/share_url/share_url_service.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/app_theme.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_content.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// The verse as a white card: image on top, then the verse and its source.
/// White in dark mode too — it is what the shared image shows.
class VerseShareCard extends StatelessWidget {
  const VerseShareCard({
    super.key,
    required this.verseOfDay,
    required this.languageCode,
  });

  final VerseOfDay verseOfDay;
  final String languageCode;

  /// The Figma card's image (350 × 263).
  static const _imageAspectRatio = 350 / 263;

  @override
  Widget build(BuildContext context) {
    final typography = VerseOfDayTypography.forShare(languageCode);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: VerseOfDayContent(
        verseOfDay: verseOfDay,
        typography: typography,
        imageAspectRatio: _imageAspectRatio,
        verseColor: Colors.black87,
        sourceColor: AppColors.textSecondary,
        useContentFontForAttribution: typography.useContentFontForAttribution,
        textAlign: TextAlign.start,
        attributionSpacing: 16,
        verseLineHeight: 1.6,
        textPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      ),
    );
  }
}

/// Shareable verse preview rendered for screenshot capture.
class VerseSharePreview extends StatelessWidget {
  const VerseSharePreview({
    super.key,
    required this.verseOfDay,
    required this.languageCode,
    required this.locale,
  });

  final VerseOfDay verseOfDay;
  final String languageCode;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final lightTheme = AppTheme.lightTheme(locale);

    return Theme(
      data: lightTheme,
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: AppColors.goldLight,
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VerseShareCard(verseOfDay: verseOfDay, languageCode: languageCode),
              const SizedBox(height: 24),
              const VerseShareBranding(
                logoSize: 32,
                sharedFromFontSize: 12,
                appTitleFontSize: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Captures and shares a verse-of-day quote image.
Future<void> shareVerseOfDayQuote(
  BuildContext context, {
  required VerseOfDay verseOfDay,
  GlobalKey? shareOriginKey,
  ScreenshotController? screenshotController,
}) async {
  File? tempFile;
  try {
    final Uint8List? imageBytes;
    if (screenshotController != null) {
      imageBytes = await screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0,
      );
    } else {
      if (!context.mounted) return;
      imageBytes = await _captureVerseShareImage(context, verseOfDay);
    }

    if (imageBytes == null || !context.mounted) return;

    final directory = await getTemporaryDirectory();
    final imagePath =
        '${directory.path}/verse_share_${DateTime.now().millisecondsSinceEpoch}.png';
    tempFile = File(imagePath);
    await tempFile.writeAsBytes(imageBytes);

    if (!context.mounted) return;

    final sharePositionOrigin = getSharePositionOrigin(
      context: context,
      globalKey: shareOriginKey,
    );
    final shareText = await _verseOfDayShareText(context);
    if (!context.mounted) return;

    final shareAnalytics = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(shareAnalyticsProvider);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(tempFile.path)],
        text: shareText,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    if (ShareAnalytics.wasUsed(result)) {
      shareAnalytics.contentShared(
        surface: ShareSurface.verse,
        targetId: verseOfDay.id,
        format: 'image',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.verse_share_error),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    }
  } finally {
    if (tempFile != null && await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }
  }
}

Future<String> _verseOfDayShareText(BuildContext context) async {
  final shareQuoteMessage = AppLocalizations.of(context)!.share_quote_message;
  final longUrl = DeepLinkUrlBuilder.homeLink().toString();
  final homeLink = await resolveShareUrl(context, longUrl);
  if (!context.mounted) return shareQuoteMessage;

  return '$shareQuoteMessage\n\n$homeLink';
}

Future<Uint8List?> _captureVerseShareImage(
  BuildContext context,
  VerseOfDay verseOfDay,
) async {
  final screenshotController = ScreenshotController();
  final languageCode = Localizations.localeOf(context).languageCode;
  final locale = Localizations.localeOf(context);
  final previewWidth = MediaQuery.sizeOf(context).width - 24;

  final overlayState = Overlay.of(context, rootOverlay: true);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (_) {
      return Positioned(
        left: -previewWidth * 2,
        top: 0,
        width: previewWidth,
        child: IgnorePointer(
          child: Screenshot(
            controller: screenshotController,
            child: VerseSharePreview(
              verseOfDay: verseOfDay,
              languageCode: languageCode,
              locale: locale,
            ),
          ),
        ),
      );
    },
  );

  overlayState.insert(overlayEntry);

  try {
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 300));

    return await screenshotController.capture(
      delay: const Duration(milliseconds: 100),
      pixelRatio: 3.0,
    );
  } finally {
    overlayEntry.remove();
  }
}

class VerseShareSheet extends StatefulWidget {
  const VerseShareSheet({super.key, required this.verseOfDay});

  final VerseOfDay verseOfDay;

  @override
  State<VerseShareSheet> createState() => _VerseShareSheetState();
}

class _VerseShareSheetState extends State<VerseShareSheet> {
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _isSharing = false;

  /// The shared image is rendered off screen (card, background and
  /// branding), so the sheet is free to follow the sheet design.
  Future<void> _shareQuote() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);
    await shareVerseOfDayQuote(
      context,
      verseOfDay: widget.verseOfDay,
      shareOriginKey: _shareButtonKey,
    );
    if (mounted) setState(() => _isSharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageCode = Localizations.localeOf(context).languageCode;
    final shareLabelFontSize = getLocalizedFontSize(AppTextSize.body);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.goldLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey800 : AppColors.grey900,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: Icon(AppAssets.x, size: 22, color: colorScheme.onSurface),
                ),
              ),
            ),
            // Scrolls on long verses so the share button is never pushed off.
            Flexible(
              child: _EdgeFadeScrollView(
                horizontalPadding: 20,
                child: VerseShareCard(
                  verseOfDay: widget.verseOfDay,
                  languageCode: languageCode,
                ),
              ),
            ),
            const SizedBox(height: 40),
            VerseShareBranding(
              logoSize: 34,
              appTitleFontSize: 14,
              showSharedFrom: false,
              appTitleColor:
                  isDark ? AppColors.textSecondaryDark : AppColors.grey900,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  key: _shareButtonKey,
                  onPressed: _isSharing ? null : _shareQuote,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color:
                          isDark ? AppColors.grey800 : AppColors.grey300,
                    ),
                  ),
                  icon:
                      _isSharing
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onSurface,
                            ),
                          )
                          : Icon(AppAssets.readerShare, size: 22),
                  label: Text(
                    localizations.share_this_verse,
                    strutStyle: AppFontConfig.tibetanStrutStyle(
                      languageCode,
                      shareLabelFontSize,
                      compact: true,
                    ),
                    style: TextStyle(
                      fontFamily: getSystemFontFamily(languageCode),
                      fontWeight: FontWeight.w600,
                      fontSize: shareLabelFontSize,
                      height: getLineHeight(languageCode),
                      leadingDistribution:
                          AppFontConfig.tibetanLeadingDistribution,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Scroll view that fades the bottom of its content into the card's white
/// while there is more below, so a long verse cut at the bottom reads as
/// scrollable. Fading to the card colour (not to transparent) keeps the card
/// white over the dark sheet. No top fade: it would haze the image, and
/// whoever scrolled already knows the card scrolls.
class _EdgeFadeScrollView extends StatefulWidget {
  const _EdgeFadeScrollView({
    required this.child,
    required this.horizontalPadding,
  });

  final Widget child;

  /// Inset of the card; the fades cover the card's width only.
  final double horizontalPadding;

  @override
  State<_EdgeFadeScrollView> createState() => _EdgeFadeScrollViewState();
}

class _EdgeFadeScrollViewState extends State<_EdgeFadeScrollView> {
  static const _fadeExtent = 56.0;
  static const _fadeColor = AppColors.surfaceWhite;

  bool _moreBelow = false;

  bool _onMetrics(ScrollMetrics metrics) {
    final below = metrics.extentAfter > 0.5;
    if (below != _moreBelow) setState(() => _moreBelow = below);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _onMetrics(n.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
              child: widget.child,
            ),
          ),
        ),
        if (_moreBelow)
          Positioned(
            left: widget.horizontalPadding,
            right: widget.horizontalPadding,
            bottom: 0,
            height: _fadeExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [_fadeColor, _fadeColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shows the verse share bottom sheet.
void showVerseShareSheet(BuildContext context, VerseOfDay verseOfDay) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    // Cap the height so a long verse leaves the barrier tappable; the preview
    // is wrapped in a Flexible scroll view and absorbs the limit.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => VerseShareSheet(verseOfDay: verseOfDay),
  );
}

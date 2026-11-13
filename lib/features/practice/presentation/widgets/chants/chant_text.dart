import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_config.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';

final RegExp _tibetan = RegExp(r'[ༀ-࿿]');

/// True when [value] holds any Tibetan script.
bool chantTextIsTibetan(String value) => _tibetan.hasMatch(value);

/// Chant text: a title in the UI font, or a verse ([isVerse]) in the
/// language's content font. Tibetan script always gets the Tibetan content
/// font with its taller line and strut.
class ChantContentText extends StatelessWidget {
  const ChantContentText(
    this.text, {
    super.key,
    required this.style,
    this.language,
    this.maxLines = 1,
    this.isVerse = false,
  });

  final String text;
  final TextStyle style;

  /// Content language when known; picks the verse font.
  final String? language;
  final int maxLines;
  final bool isVerse;

  @override
  Widget build(BuildContext context) {
    final isTibetan = chantTextIsTibetan(text);
    final fontSize = style.fontSize ?? 14;
    final resolved =
        isTibetan
            ? getContentTextStyle(
              AppConfig.tibetanLanguageCode,
              style.copyWith(
                height: AppFontConfig.tibetanContentLineHeight,
                leadingDistribution: AppFontConfig.tibetanLeadingDistribution,
              ),
            )
            : isVerse
            ? getContentTextStyle(language, style)
            : style;
    return Text(
      text,
      style: resolved,
      strutStyle:
          isTibetan
              ? AppFontConfig.tibetanStrutStyle(
                AppConfig.tibetanLanguageCode,
                fontSize,
              )
              : null,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The 40pt outlined circle used for the play and open buttons.
class ChantCircleButton extends StatelessWidget {
  const ChantCircleButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.semanticLabel,
    this.onPressed,
  });

  final IconData icon;
  final double iconSize;
  final String semanticLabel;
  final VoidCallback? onPressed;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withAlpha(150)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: color),
    );
    if (onPressed == null) {
      return ExcludeSemantics(child: circle);
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onPressed,
        radius: size / 2 + 4,
        child: ExcludeSemantics(child: circle),
      ),
    );
  }
}

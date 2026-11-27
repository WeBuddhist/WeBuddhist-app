import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_list_continuation.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

/// Message composer pinned to the bottom of the chat, per the chat composer
/// component in Figma: a round + for media, then a pill field. The send
/// button only exists once something has been typed.
///
/// [isSending] is about a text message only. Media goes out in its own
/// bubble in the thread, so the composer stays free while it uploads.
class GroupChatComposer extends StatelessWidget {
  const GroupChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.isSending,
    required this.onSubmit,
    this.enabled = true,
    this.addMediaEnabled = true,
    this.onAddMediaPressed,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool isSending;
  final VoidCallback onSubmit;
  final bool enabled;

  /// False greys out the + while a photo or video message is still sending,
  /// so a second pick can't be dropped.
  final bool addMediaEnabled;
  final VoidCallback? onAddMediaPressed;

  static const double _buttonSize = 44;
  static const double _gap = 8;

  /// #DADADA ring around the +, #D3D3D3 hairline around the field.
  static const Color _buttonBorder = Color(0xFFDADADA);
  static const Color _fieldBorder = Color(0xFFD3D3D3);
  static const Color _hint = Color(0xFF4E4E4E);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafePadding = MediaQuery.viewPaddingOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        keyboardInset > 0 ? keyboardInset + 8 : bottomSafePadding + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onAddMediaPressed != null) ...[
            _AddMediaButton(
              onPressed: enabled && addMediaEnabled ? onAddMediaPressed : null,
              isDark: isDark,
            ),
            const SizedBox(width: _gap),
          ],
          Expanded(
            child: _MessageField(
              controller: controller,
              focusNode: focusNode,
              isDark: isDark,
              hintText: hintText,
              enabled: enabled,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              // Nothing typed, nothing to send: the button is absent rather
              // than disabled, and the field takes the full width.
              if (!hasText && !isSending) return const SizedBox.shrink();
              final canSend = enabled && hasText && !isSending;
              return Padding(
                padding: const EdgeInsets.only(left: _gap),
                child: _SendButton(
                  canSend: canSend,
                  isSending: isSending,
                  isDark: isDark,
                  onPressed: canSend ? onSubmit : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  const _AddMediaButton({required this.onPressed, required this.isDark});

  final VoidCallback? onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final iconColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    return Material(
      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite,
      shape: CircleBorder(
        side: BorderSide(
          color: isDark ? AppColors.grey800 : GroupChatComposer._buttonBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: GroupChatComposer._buttonSize,
          height: GroupChatComposer._buttonSize,
          child: Icon(
            AppAssets.plus,
            size: 24,
            color: enabled ? iconColor : iconColor.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _MessageField extends StatelessWidget {
  const _MessageField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.hintText,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final String hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? AppColors.grey800 : GroupChatComposer._fieldBorder;
    final fillColor =
        isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: borderColor, width: 0.5),
    );

    // 16/24 text with 8.5 above and below: 41 tall on one line, as drawn.
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.5),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        minLines: 1,
        maxLines: 5,
        // Return adds a line rather than sending: with a send button always
        // at hand there is no other way to type a second line, and `send`
        // made multi-line messages impossible to compose.
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        // Return inside a list carries the marker on; Return on an empty item
        // ends the list.
        inputFormatters: const [ChatListContinuationFormatter()],
        style: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 16,
            height: 1.5,
            color:
                isDark ? AppColors.textTertiaryDark : GroupChatComposer._hint,
          ),
          filled: true,
          fillColor: fillColor,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(17, 8.5, 17, 8.5),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(
              color: isDark ? AppColors.grey600 : AppColors.grey400,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.canSend,
    required this.isSending,
    required this.isDark,
    required this.onPressed,
  });

  final bool canSend;
  final bool isSending;
  final bool isDark;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDark ? AppColors.surfaceWhite : Colors.black;
    final foregroundColor = isDark ? Colors.black : AppColors.surfaceWhite;

    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: GroupChatComposer._buttonSize,
          height: GroupChatComposer._buttonSize,
          child: Center(
            child:
                isSending
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foregroundColor,
                      ),
                    )
                    : Icon(
                      AppAssets.paperPlaneRight,
                      size: 22,
                      color: foregroundColor,
                    ),
          ),
        ),
      ),
    );
  }
}

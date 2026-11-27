import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_book_colors.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/collection_name_validation.dart';
import 'package:flutter_pecha/shared/domain/validators/collection_name_validator.dart';

/// Shows [CollectionNameDialog]; resolves to the sanitized name, or `null`
/// when cancelled or dismissed.
Future<String?> showCollectionNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder:
        (_) => CollectionNameDialog(
          title: title,
          actionLabel: actionLabel,
          initialName: initialName,
        ),
  );
}

/// The same prompt as [showCollectionNameDialog], as a bottom sheet above the
/// keyboard, with [hintText] in the field while it is empty. Resolves to the
/// sanitized name, or `null` when dismissed.
Future<String?> showCollectionNameSheet(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialName = '',
  String? hintText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => CollectionNameDialog(
          title: title,
          actionLabel: actionLabel,
          initialName: initialName,
          hintText: hintText,
          asSheet: true,
        ),
  );
}

/// Single-field name prompt shared by "New Collection" and "Change title",
/// so both keep the same field and button styling. With [asSheet] it lays
/// out as a bottom sheet instead of a dialog; see [showCollectionNameSheet].
class CollectionNameDialog extends StatefulWidget {
  const CollectionNameDialog({
    super.key,
    required this.title,
    required this.actionLabel,
    this.initialName = '',
    this.hintText,
    this.asSheet = false,
  });

  final String title;
  final String actionLabel;
  final String initialName;

  /// Placeholder shown while the field is empty.
  final String? hintText;
  final bool asSheet;

  @override
  State<CollectionNameDialog> createState() => _CollectionNameDialogState();
}

class _CollectionNameDialogState extends State<CollectionNameDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Shown under the field after a failed submit; cleared on the next edit.
  CollectionNameValidationError? _error;

  bool get _isValid =>
      CollectionNameValidator.validate(_controller.text) == null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCancel() => Navigator.of(context).pop();

  void _onSubmit() {
    final error = CollectionNameValidator.validate(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(
      context,
    ).pop(CollectionNameValidator.sanitize(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? AppColors.cardBackgroundDark : AppColors.surfaceWhite;
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final cancelColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final actionBackground =
        _isValid
            ? (isDark ? AppColors.surfaceWhite : AppColors.textPrimary)
            : (isDark ? AppColors.grey900 : AppColors.grey500);
    final actionForeground =
        isDark ? AppColors.textPrimary : AppColors.onPrimary;
    final fieldBorder = isDark ? AppColors.cardBorderDark : AppColors.grey900;
    final fieldFill = isDark ? AppColors.surfaceDark : AppColors.surfaceWhite;

    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      textInputAction: TextInputAction.done,
      maxLength: CollectionNameValidator.maxLength,
      buildCounter:
          (
            context, {
            required currentLength,
            required isFocused,
            required maxLength,
          }) => const SizedBox.shrink(),
      onChanged: (_) => setState(() => _error = null),
      onSubmitted: (_) => _onSubmit(),
      style: TextStyle(fontSize: 15, color: titleColor),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          fontSize: 15,
          color: ChantBookColors.secondaryText(isDark),
        ),
        errorText:
            _error == null
                ? null
                : collectionNameErrorMessage(context.l10n, _error!),
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder, width: 1.5),
        ),
      ),
    );

    if (widget.asSheet) {
      return _buildSheet(
        isDark: isDark,
        titleColor: titleColor,
        actionBackground: actionBackground,
        actionForeground: actionForeground,
        field: field,
      );
    }

    final form = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 16),
        field,
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _onCancel,
              style: TextButton.styleFrom(
                foregroundColor: cancelColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                context.l10n.cancel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: actionBackground,
              shape: const StadiumBorder(),
              child: InkWell(
                onTap: _isValid ? _onSubmit : null,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    widget.actionLabel,
                    style: TextStyle(
                      color: actionForeground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Dialog(
      backgroundColor: cardColor,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: form,
      ),
    );
  }

  /// The New chant book sheet: a title band with a close button, the field,
  /// and one full-width action button, lifted above the keyboard.
  Widget _buildSheet({
    required bool isDark,
    required Color titleColor,
    required Color actionBackground,
    required Color actionForeground,
    required Widget field,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ColoredBox(
          color: ChantBookColors.sheet(isDark),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: ChantBookColors.tint(isDark),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: titleColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.close,
                              icon: Icon(AppAssets.x, color: titleColor),
                              onPressed: _onCancel,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field,
                      const SizedBox(height: 14),
                      Material(
                        color: actionBackground,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          onTap: _isValid ? _onSubmit : null,
                          customBorder: const StadiumBorder(),
                          child: SizedBox(
                            height: 50,
                            child: Center(
                              child: Text(
                                widget.actionLabel,
                                style: TextStyle(
                                  color: actionForeground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

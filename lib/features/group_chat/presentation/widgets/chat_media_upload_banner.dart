import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

/// Progress while chat photos or video are uploading, with optional cancel.
class ChatMediaUploadBanner extends StatelessWidget {
  const ChatMediaUploadBanner({
    super.key,
    required this.current,
    required this.total,
    required this.onCancel,
  });

  final int current;
  final int total;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = context.l10n.group_chat_media_sending(current, total);
    final progress = total == 0 ? 0.0 : current / total;

    return Material(
      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
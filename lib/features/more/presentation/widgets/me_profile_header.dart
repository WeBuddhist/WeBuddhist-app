import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/auth/domain/entities/user.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';

/// Instagram-style profile header: avatar, display name and an edit pencil,
/// with the bio below. The username is the app bar title; the email lives in
/// Settings.
class MeProfileHeader extends StatelessWidget {
  const MeProfileHeader({super.key, required this.user, this.onEditProfile});

  final User user;
  final VoidCallback? onEditProfile;

  static const _avatarSize = 80.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final avatarUrl = user.avatarUrl ?? '';
    final name = user.visibleName;
    final bio = user.aboutMe?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Hero(
                tag: 'profile-avatar',
                child: _Avatar(avatarUrl: avatarUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                // Personal details stay hidden in Clarity recordings.
                child: ClarityMask(
                  child:
                      name.isNotEmpty
                          ? Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
              ),
              if (onEditProfile != null)
                IconButton(
                  icon: Icon(
                    AppAssets.pencilSimple,
                    size: 24,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  tooltip:
                      AppLocalizations.of(context)?.settings_edit_profile,
                  onPressed: onEditProfile,
                ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClarityMask(
                child: Text(
                  bio,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.grey400 : AppColors.grey600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MeProfileHeader._avatarSize,
      height: MeProfileHeader._avatarSize,
      child: ClipOval(
        child:
            avatarUrl.isNotEmpty
                ? CachedNetworkImageWidget(
                  imageUrl: avatarUrl,
                  width: MeProfileHeader._avatarSize,
                  height: MeProfileHeader._avatarSize,
                  fit: BoxFit.cover,
                  placeholder: const ColoredBox(color: AppColors.grey300),
                  errorWidget: ColoredBox(
                    color: AppColors.grey300,
                    child: Icon(
                      AppAssets.profile,
                      size: 36,
                      color: AppColors.grey600,
                    ),
                  ),
                )
                : DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.grey300, width: 1.5),
                  ),
                  child: Icon(
                    AppAssets.profile,
                    size: 36,
                    color: AppColors.grey600,
                  ),
                ),
      ),
    );
  }
}

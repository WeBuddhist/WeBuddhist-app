import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';

class ChatMediaPickerSheet extends StatelessWidget {
  const ChatMediaPickerSheet({
    super.key,
    required this.onMediaSelected,
  });

  final Function(List<File> files, String mediaType, String caption) onMediaSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Container(
      height: 251,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey800 : AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add to Chat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          _PickerRow(
            icon: AppAssets.photoLibrary,
            title: 'Gallery',
            subtitle: 'Share photos and videos from your phone',
            isDark: isDark,
            onTap: () async {
              Navigator.pop(context);
              _openGalleryPicker(context);
            },
          ),
          const Divider(height: 24),
          _PickerRow(
            icon: AppAssets.camera,
            title: 'Camera',
            subtitle: 'Take a photo or record a video',
            isDark: isDark,
            onTap: () async {
              Navigator.pop(context);
              _openCameraPicker(context);
            },
          ),
        ],
      ),
    );
  }

  void _openGalleryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupChatGalleryPicker(
        onMediaSelected: onMediaSelected,
      ),
    );
  }

  void _openCameraPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: 180,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camera',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final picker = ImagePicker();
                        final photo = await picker.pickImage(source: ImageSource.camera);
                        if (photo != null) {
                          onMediaSelected([File(photo.path)], 'IMAGE', '');
                        }
                      },
                      icon: const Icon(AppAssets.camera),
                      label: const Text('Photo'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final picker = ImagePicker();
                        final video = await picker.pickVideo(
                          source: ImageSource.camera,
                          maxDuration: const Duration(seconds: 120),
                        );
                        if (video != null) {
                          onMediaSelected([File(video.path)], 'VIDEO', '');
                        }
                      },
                      icon: const Icon(AppAssets.videoCamera),
                      label: const Text('Video'),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.grey800 : AppColors.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            AppAssets.caretRight,
            color: isDark ? AppColors.grey500 : AppColors.grey400,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class GroupChatGalleryPicker extends StatefulWidget {
  const GroupChatGalleryPicker({
    super.key,
    required this.onMediaSelected,
  });

  final Function(List<File> files, String mediaType, String caption) onMediaSelected;

  @override
  State<GroupChatGalleryPicker> createState() => _GroupChatGalleryPickerState();
}

class _GroupChatGalleryPickerState extends State<GroupChatGalleryPicker> {
  bool _hasPermission = false;
  bool _loading = true;
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selectedAssets = [];
  final TextEditingController _captionController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoad() async {
    final result = await PhotoManager.requestPermissionExtend();
    if (result.hasAccess) {
      setState(() {
        _hasPermission = true;
      });
      _loadAssets();
    } else {
      setState(() {
        _hasPermission = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadAssets() async {
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );
      if (paths.isNotEmpty) {
        final recentPath = paths.first;
        final assets = await recentPath.getAssetListPaged(page: 0, size: 100);
        setState(() {
          _assets = assets;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleAssetSelection(AssetEntity entity) async {
    setState(() {
      _errorMessage = null;
    });

    if (entity.type == AssetType.video) {
      // Check video limits
      final duration = entity.duration; // in seconds
      final file = await entity.file;
      final sizeInBytes = file != null ? await file.length() : 0;
      final sizeInMb = sizeInBytes / (1024 * 1024);

      if (duration > 120) {
        setState(() {
          _errorMessage = 'This video is $duration seconds. Videos can be up to 120 seconds, so it can’t be added.';
        });
        return;
      }

      if (sizeInMb > 40) {
        setState(() {
          _errorMessage = 'This video is ${sizeInMb.toStringAsFixed(1)} MB. Videos can be up to 40 MB, so it can’t be added.';
        });
        return;
      }

      // Selection must only be this video, never both photo and video
      setState(() {
        _selectedAssets.clear();
        _selectedAssets.add(entity);
      });
    } else {
      // Photo selection
      if (_selectedAssets.any((a) => a.type == AssetType.video)) {
        // Clear video if selecting a photo
        setState(() {
          _selectedAssets.clear();
        });
      }

      if (_selectedAssets.contains(entity)) {
        setState(() {
          _selectedAssets.remove(entity);
        });
      } else {
        if (_selectedAssets.length >= 10) {
          setState(() {
            _errorMessage = 'You can select up to 10 photos.';
          });
          return;
        }
        setState(() {
          _selectedAssets.add(entity);
        });
      }
    }
  }

  Future<void> _handleSend() async {
    if (_selectedAssets.isEmpty) return;

    final List<File> files = [];
    String mediaType = 'IMAGE';

    for (final asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        files.add(file);
      }
      if (asset.type == AssetType.video) {
        mediaType = 'VIDEO';
      }
    }

    if (files.isNotEmpty) {
      Navigator.pop(context);
      widget.onMediaSelected(files, mediaType, _captionController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(AppAssets.x),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? Colors.white : Colors.black,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Gallery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // balance close button
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Body
          Expanded(
            child: _buildBody(isDark),
          ),

          // Error Message Bar
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Bottom Send / Caption Bar
          if (_selectedAssets.isNotEmpty) _buildBottomBar(isDark),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppAssets.prohibit, size: 48, color: AppColors.grey500),
              const SizedBox(height: 16),
              const Text(
                'Permission Denied',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant photo library permissions in Settings to pick photos and videos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey500),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => PhotoManager.openSetting(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (_assets.isEmpty) {
      return const Center(
        child: Text('No photos or videos found on device.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1, // square cells
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final isSelected = _selectedAssets.contains(asset);
        final selectionIndex = _selectedAssets.indexOf(asset);

        return InkWell(
          onTap: () => _toggleAssetSelection(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize(250, 250),
                fit: BoxFit.cover,
              ),
              if (asset.type == AssetType.video)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      const Icon(AppAssets.videoCamera, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(asset.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              // Dim overlay when selected
              if (isSelected)
                Container(color: Colors.black26),
              // Circle selector badge
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.black38,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: isSelected
                        ? (asset.type == AssetType.video
                            ? const Icon(AppAssets.check, size: 12, color: Colors.white)
                            : Text(
                                '${selectionIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ))
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final isVideo = _selectedAssets.any((a) => a.type == AssetType.video);
    final count = _selectedAssets.length;
    final hint = isVideo ? 'Add caption for video...' : 'Add caption for $count photo(s)...';

    return SafeArea(
      child: Container(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceWhite,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _captionController,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _handleSend,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      AppAssets.paperPlaneRight,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

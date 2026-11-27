import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_limits.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_camera_preview_screen.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_badges.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// Amber ring and badge on selected gallery cells, per the send-flow mocks.
const _selectionColor = Color(0xFFF5A316);

/// "Share in chat" sheet, per the Attach Sheet component.
const _sheetFill = Color(0xFFFFF8ED);
const _sheetHandle = Color(0xFF958778);
const _optionBorder = Color(0xFFD3D3D3);

/// Dim behind the share sheet (black at 40%).
const chatSheetBarrier = Color(0x66000000);

/// Red used for the "video too large" line and badge icon.
const chatMediaErrorColor = Color(0xFFC22929);

typedef ChatMediaSelected =
    void Function(List<File> files, String mediaType, String caption);

/// "Share in chat": Gallery or Camera.
class ChatMediaPickerSheet extends StatelessWidget {
  const ChatMediaPickerSheet({super.key, required this.onMediaSelected});

  final ChatMediaSelected onMediaSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Captured before the sheet pops: the sheet's own context is gone by the
    // time the gallery or camera needs a navigator.
    final navigator = Navigator.of(context, rootNavigator: true);
    return _OptionsSheet(
      title: l10n.group_chat_media_share_title,
      options: [
        _ShareOptionData(
          icon: AppAssets.photoLibrary,
          title: l10n.group_chat_media_gallery,
          onTap: () {
            Navigator.pop(context);
            _openGalleryPicker(navigator.context);
          },
        ),
        _ShareOptionData(
          icon: AppAssets.camera,
          title: l10n.group_chat_media_camera,
          onTap: () {
            Navigator.pop(context);
            _openCameraChoice(navigator);
          },
        ),
      ],
    );
  }

  void _openGalleryPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: chatSheetBarrier,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupChatGalleryPicker(onMediaSelected: onMediaSelected),
    );
  }

  /// The phone's own camera does the capturing; the app only asks which
  /// mode, then shows the capture with a caption before it is sent.
  void _openCameraChoice(NavigatorState navigator) {
    showModalBottomSheet<void>(
      context: navigator.context,
      useRootNavigator: true,
      barrierColor: chatSheetBarrier,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return _OptionsSheet(
          title: l10n.group_chat_media_camera,
          options: [
            _ShareOptionData(
              icon: AppAssets.camera,
              title: l10n.group_chat_media_photo,
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_capture(navigator, isVideo: false));
              },
            ),
            _ShareOptionData(
              icon: AppAssets.videoCamera,
              title: l10n.group_chat_media_video,
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_capture(navigator, isVideo: true));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _capture(NavigatorState navigator, {required bool isVideo}) async {
    final picker = ImagePicker();
    final XFile? captured =
        isVideo
            ? await picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: kChatMaxVideoDuration,
            )
            : await picker.pickImage(source: ImageSource.camera);
    if (captured == null || !navigator.mounted) return;
    await showChatCameraPreview(
      navigator,
      file: File(captured.path),
      isVideo: isVideo,
      onSend: (file, caption) {
        onMediaSelected([file], isVideo ? 'VIDEO' : 'IMAGE', caption);
      },
    );
  }
}

class _ShareOptionData {
  const _ShareOptionData({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.title, required this.options});

  final String title;
  final List<_ShareOptionData> options;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.surfaceVariantDark : _sheetFill;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: backgroundColor,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.grey800 : _sheetHandle,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              strutStyle: context.tibetanStrutStyle(17, compact: true),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _ShareOption(data: options[i], isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({required this.data, required this.isDark});

  final _ShareOptionData data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.grey800 : _optionBorder;
    final fill = isDark ? AppColors.grey800 : AppColors.surfaceWhite;

    // 68 tall: 12 + a 44 icon tile + 12, with 14 at the sides.
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Icon(data.icon, size: 24, color: titleColor),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
              Icon(
                AppAssets.caretRight,
                size: 20,
                color: isDark ? AppColors.grey500 : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In-app gallery: a 3-column grid with numbered selection, then a caption
/// and send, as in the "Gallery" frame.
class GroupChatGalleryPicker extends StatefulWidget {
  const GroupChatGalleryPicker({super.key, required this.onMediaSelected});

  final ChatMediaSelected onMediaSelected;

  @override
  State<GroupChatGalleryPicker> createState() => _GroupChatGalleryPickerState();
}

class _GroupChatGalleryPickerState extends State<GroupChatGalleryPicker> {
  bool _hasPermission = false;
  bool _limitedAccess = false;
  bool _loading = true;
  bool _sending = false;
  List<AssetEntity> _assets = [];

  /// The device's "all photos" collection (Recents on iOS), newest first,
  /// read a page at a time as the grid scrolls, so the whole library is
  /// reachable rather than just its first screenful.
  AssetPathEntity? _path;
  int _totalCount = 0;
  bool _loadingMore = false;
  static const _pageSize = 80;

  bool get _hasMore => _assets.length < _totalCount;
  final List<AssetEntity> _selectedAssets = [];

  /// Videos known to break the limits, keyed by asset id. Duration is known
  /// straight away; size only once the file is read, and only for videos
  /// already on the device, so the grid never pulls a clip down from iCloud
  /// just to measure it.
  final Map<String, ChatVideoProblem> _videoProblems = {};
  final Map<String, int> _videoBytes = {};

  /// The problem shown in the red line above the caption.
  ChatVideoProblem? _shownProblem;
  bool _photoLimitHit = false;

  final _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    PhotoManager.addChangeCallback(_onLibraryChanged);
    unawaited(PhotoManager.startChangeNotify());
    _requestPermissionAndLoad();
  }

  @override
  void dispose() {
    PhotoManager.removeChangeCallback(_onLibraryChanged);
    unawaited(PhotoManager.stopChangeNotify());
    _captionController.dispose();
    super.dispose();
  }

  void _onLibraryChanged(MethodCall call) {
    if (!mounted || !_hasPermission) return;
    unawaited(_loadAssets());
  }

  Future<void> _requestPermissionAndLoad() async {
    final result = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (result.hasAccess) {
      setState(() {
        _hasPermission = true;
        _limitedAccess = result == PermissionState.limited;
      });
      await _loadAssets();
    } else {
      setState(() {
        _hasPermission = false;
        _limitedAccess = false;
        _loading = false;
      });
    }
  }

  /// Opens the system picker so a restricted grant can include more photos.
  Future<void> _selectMorePhotos() async {
    try {
      await PhotoManager.presentLimited(type: RequestType.common);
    } catch (_) {
      await PhotoManager.openSetting();
    }
    if (!mounted) return;
    await _loadAssets();
  }

  /// (Re)reads the library from the top, keeping as many items as were
  /// already loaded so a library change does not throw the user back up.
  Future<void> _loadAssets() async {
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (paths.isEmpty) {
        if (!mounted) return;
        setState(() {
          _path = null;
          _assets = [];
          _totalCount = 0;
          _loading = false;
        });
        return;
      }
      final path = paths.first;
      final total = await path.assetCountAsync;
      final want = _assets.length > _pageSize ? _assets.length : _pageSize;
      final assets =
          total == 0
              ? const <AssetEntity>[]
              : await path.getAssetListRange(
                start: 0,
                end: want < total ? want : total,
              );
      if (!mounted) return;
      setState(() {
        _path = path;
        _totalCount = total;
        _assets = assets;
        _loading = false;
        _markTooLong(assets);
      });
      unawaited(_measureLocalVideos(assets));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Reads the next page once the grid nears the end of what is loaded.
  Future<void> _loadMore() async {
    final path = _path;
    if (path == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final start = _assets.length;
      final end =
          start + _pageSize < _totalCount ? start + _pageSize : _totalCount;
      final page = await path.getAssetListRange(start: start, end: end);
      if (!mounted) return;
      setState(() {
        _assets = [..._assets, ...page];
        // A short page means the count was stale; stop asking.
        if (page.length < end - start) _totalCount = _assets.length;
        _markTooLong(page);
      });
      unawaited(_measureLocalVideos(page));
    } catch (_) {
      // Leave the loaded part in place; the next scroll tries again.
    } finally {
      _loadingMore = false;
    }
  }

  /// Duration is on the asset itself, so long videos are marked at once.
  void _markTooLong(List<AssetEntity> assets) {
    for (final asset in assets) {
      if (asset.type != AssetType.video) continue;
      final tooLong = validateChatVideo(
        bytes: 0,
        duration: Duration(seconds: asset.duration),
      );
      if (tooLong != null) _videoProblems[asset.id] = tooLong;
    }
  }

  /// Reads the size of each on-device video so an oversized one is marked
  /// before it is tapped. One at a time, in grid order.
  Future<void> _measureLocalVideos(List<AssetEntity> assets) async {
    for (final asset in assets) {
      if (!mounted) return;
      if (asset.type != AssetType.video) continue;
      if (_videoBytes.containsKey(asset.id)) continue;
      try {
        if (!await asset.isLocallyAvailable()) continue;
        final file = await asset.originFile;
        if (file == null) continue;
        final bytes = await file.length();
        if (!mounted) return;
        _videoBytes[asset.id] = bytes;
        final problem = validateChatVideo(
          bytes: bytes,
          duration: Duration(seconds: asset.duration),
        );
        if (problem is ChatVideoTooLarge) {
          setState(() => _videoProblems[asset.id] = problem);
        }
      } catch (_) {
        // Size stays unknown; the tap re-checks.
      }
    }
  }

  Future<void> _toggleAssetSelection(AssetEntity entity) async {
    setState(() {
      _shownProblem = null;
      _photoLimitHit = false;
    });

    if (entity.type == AssetType.video) {
      var problem = _videoProblems[entity.id];
      if (problem == null && !_videoBytes.containsKey(entity.id)) {
        final file = await entity.file;
        final bytes = file != null ? await file.length() : 0;
        _videoBytes[entity.id] = bytes;
        problem = validateChatVideo(
          bytes: bytes,
          duration: Duration(seconds: entity.duration),
        );
        if (problem != null) _videoProblems[entity.id] = problem;
      }
      if (!mounted) return;
      if (problem != null) {
        setState(() => _shownProblem = problem);
        return;
      }
      // One video, never alongside photos: the API takes 1-10 photos or one
      // video per message.
      setState(() {
        final wasSelected = _selectedAssets.contains(entity);
        _selectedAssets.clear();
        if (!wasSelected) _selectedAssets.add(entity);
      });
      return;
    }

    setState(() {
      _selectedAssets.removeWhere((a) => a.type == AssetType.video);
      if (_selectedAssets.contains(entity)) {
        _selectedAssets.remove(entity);
      } else if (_selectedAssets.length >= kChatMaxPhotos) {
        _photoLimitHit = true;
      } else {
        _selectedAssets.add(entity);
      }
    });
  }

  Future<void> _handleSend() async {
    if (_selectedAssets.isEmpty || _sending) return;
    setState(() => _sending = true);

    final files = <File>[];
    var mediaType = 'IMAGE';
    for (final asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) files.add(file);
      if (asset.type == AssetType.video) mediaType = 'VIDEO';
    }

    if (!mounted) return;
    if (files.isEmpty) {
      setState(() => _sending = false);
      return;
    }
    final caption = _captionController.text.trim();
    Navigator.pop(context);
    widget.onMediaSelected(files, mediaType, caption);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.surfaceVariantDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.92,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(AppAssets.x, size: 24),
                  tooltip: context.l10n.close,
                  onPressed: () => Navigator.pop(context),
                  color: textColor,
                ),
                Expanded(
                  child: Text(
                    context.l10n.group_chat_media_gallery,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
          if (_limitedAccess && _hasPermission) _limitedAccessBar(isDark),
          Expanded(child: _buildBody(isDark)),
          if (_hasPermission && !_loading) ...[
            if (_errorText(context) case final error?)
              ChatMediaErrorLine(text: error),
            _buildCaptionBar(isDark),
          ],
        ],
      ),
    );
  }

  String? _errorText(BuildContext context) {
    final problem = _shownProblem;
    if (problem != null) {
      return chatVideoProblemMessage(context, problem, fromCamera: false);
    }
    if (_photoLimitHit) {
      return context.l10n.group_chat_media_photo_limit(kChatMaxPhotos);
    }
    return null;
  }

  Widget _buildBody(bool isDark) {
    final l10n = context.l10n;
    if (_loading) {
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemCount: 18,
        itemBuilder: (_, _) => const ChatMediaSkeleton(),
      );
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppAssets.prohibit, size: 48, color: AppColors.grey500),
              const SizedBox(height: 16),
              Text(
                l10n.group_chat_media_permission_title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.group_chat_media_permission_body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey500),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => PhotoManager.openSetting(),
                child: Text(l10n.group_chat_media_open_settings),
              ),
            ],
          ),
        ),
      );
    }

    if (_assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _limitedAccess
                ? l10n.group_chat_media_empty_limited
                : l10n.group_chat_media_empty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey500),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      // A row of skeleton tiles under the loaded part while more exist.
      itemCount: _assets.length + (_hasMore ? 6 : 0),
      itemBuilder: (context, index) {
        if (index >= _assets.length - 24 && _hasMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
        }
        if (index >= _assets.length) return const ChatMediaSkeleton();
        final asset = _assets[index];
        final selectionIndex = _selectedAssets.indexOf(asset);
        return _GalleryTile(
          key: ValueKey(asset.id),
          asset: asset,
          selectionNumber: selectionIndex < 0 ? null : selectionIndex + 1,
          problem: _videoProblems[asset.id],
          onTap: () => _toggleAssetSelection(asset),
        );
      },
    );
  }

  Widget _limitedAccessBar(bool isDark) {
    final textColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Material(
      color: isDark ? AppColors.grey900 : AppColors.grey100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.group_chat_media_limited_access,
                style: TextStyle(fontSize: 13, color: textColor),
              ),
            ),
            TextButton(
              onPressed: _selectMorePhotos,
              child: Text(context.l10n.group_chat_media_select_more),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionBar(bool isDark) {
    final canSend = _selectedAssets.isNotEmpty && !_sending;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: ChatCaptionField(
                controller: _captionController,
                hintText: context.l10n.group_chat_media_caption_hint,
                fill: isDark ? AppColors.grey800 : AppColors.surfaceWhite,
                textColor:
                    isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                hintColor:
                    isDark ? AppColors.textTertiaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            ChatSendButton(
              enabled: canSend,
              onPressed: _handleSend,
              color: isDark ? AppColors.surfaceWhite : Colors.black,
              iconColor: isDark ? Colors.black : Colors.white,
              disabledColor: isDark ? AppColors.grey800 : AppColors.grey300,
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    super.key,
    required this.asset,
    required this.selectionNumber,
    required this.problem,
    required this.onTap,
  });

  final AssetEntity asset;
  final int? selectionNumber;
  final ChatVideoProblem? problem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectionNumber != null;
    final isVideo = asset.type == AssetType.video;
    final problem = this.problem;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetEntityImage(
            asset,
            isOriginal: false,
            thumbnailSize: const ThumbnailSize(250, 250),
            fit: BoxFit.cover,
            frameBuilder:
                (_, child, frame, sync) =>
                    frame == null && !sync ? const ChatMediaSkeleton() : child,
            errorBuilder:
                (_, _, _) => const ColoredBox(
                  color: AppColors.grey300,
                  child: Icon(AppAssets.image, color: AppColors.grey600),
                ),
          ),
          if (isSelected) ...[
            ColoredBox(color: Colors.white.withValues(alpha: 0.25)),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: _selectionColor, width: 3),
              ),
            ),
          ],
          if (problem != null) ...[
            ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppAssets.warningCircle,
                      size: 18,
                      color: chatMediaErrorColor,
                    ),
                  ),
                  if (problem is ChatVideoTooLarge) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${problem.megabytes} MB',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (isVideo)
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                children: [
                  const Icon(AppAssets.play, size: 14, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    formatChatDuration(Duration(seconds: asset.duration)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          if (problem == null)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? _selectionColor
                          : Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child:
                    isSelected
                        ? Center(
                          child: Text(
                            '$selectionNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// The red "too large" line shared by the gallery and the camera preview.
class ChatMediaErrorLine extends StatelessWidget {
  const ChatMediaErrorLine({super.key, required this.text, this.onDark = false});

  final String text;

  /// The camera preview is black; the red is lifted a little to stay legible.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? const Color(0xFFFF6B6B) : chatMediaErrorColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(AppAssets.warningCircle, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded caption input used by the gallery and the camera preview.
class ChatCaptionField extends StatelessWidget {
  const ChatCaptionField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.fill,
    required this.textColor,
    required this.hintColor,
  });

  final TextEditingController controller;
  final String hintText;
  final Color fill;
  final Color textColor;
  final Color hintColor;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 16, color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 16, color: hintColor),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// 44px round paper-plane button.
class ChatSendButton extends StatelessWidget {
  const ChatSendButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.color,
    required this.iconColor,
    required this.disabledColor,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final Color color;
  final Color iconColor;
  final Color disabledColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.group_chat_media_send,
      child: Material(
        color: enabled ? color : disabledColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              AppAssets.paperPlaneRight,
              size: 22,
              color: enabled ? iconColor : iconColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens [url] in the chat's own browser screen ("in app browser" frame).
Future<void> showChatWebView(NavigatorState navigator, Uri url) {
  return navigator.push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      settings: const RouteSettings(name: 'chat-web-view'),
      builder: (_) => ChatWebViewScreen(url: url),
    ),
  );
}

/// A web page opened from a chat link: close, page title over a lock and the
/// domain, a thin progress bar, then back / forward and "Open in browser".
class ChatWebViewScreen extends StatefulWidget {
  const ChatWebViewScreen({super.key, required this.url, this.controller});

  final Uri url;

  /// Tests pass a controller; the app builds its own.
  final WebViewController? controller;

  @override
  State<ChatWebViewScreen> createState() => _ChatWebViewScreenState();
}

enum _MenuAction { copy, share, openExternal }

class _ChatWebViewScreenState extends State<ChatWebViewScreen> {
  late final WebViewController _controller;
  late Uri _current;
  String? _title;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _current = widget.url;
    _controller = widget.controller ?? WebViewController();
    if (widget.controller == null) {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageStarted: (url) {
              if (!mounted) return;
              setState(() {
                _failed = false;
                _current = Uri.tryParse(url) ?? _current;
              });
            },
            onPageFinished: (_) => _refreshState(),
            onUrlChange: (change) {
              final url = change.url;
              if (url != null && mounted) {
                setState(() => _current = Uri.tryParse(url) ?? _current);
              }
              _refreshState();
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted) {
                setState(() => _failed = true);
              }
            },
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              // mailto:, tel:, app links and the like go to their own app.
              if (uri != null &&
                  uri.scheme != 'http' &&
                  uri.scheme != 'https' &&
                  uri.scheme != 'about') {
                launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(widget.url);
    }
  }

  Future<void> _refreshState() async {
    final title = await _controller.getTitle();
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _title = (title == null || title.trim().isEmpty) ? null : title.trim();
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _openExternal() async {
    await launchUrl(_current, mode: LaunchMode.externalApplication);
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.copy:
        await Clipboard.setData(ClipboardData(text: _current.toString()));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.group_chat_browser_link_copied)),
        );
      case _MenuAction.share:
        await SharePlus.instance.share(ShareParams(uri: _current));
      case _MenuAction.openExternal:
        await _openExternal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary =
        isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
    final disabled = isDark ? AppColors.grey800 : AppColors.grey300;
    final chrome = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceLight;
    final host = _current.host.isEmpty ? _current.toString() : _current.host;
    final secure = _current.scheme == 'https';

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceWhite,
      appBar: AppBar(
        backgroundColor: chrome,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(AppAssets.x, color: primary),
          tooltip: l10n.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title ?? host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secure) ...[
                  Icon(AppAssets.lock, size: 12, color: secondary),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            icon: Icon(AppAssets.dotsThree, color: primary),
            onSelected: _onMenu,
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: _MenuAction.copy,
                    child: Text(l10n.group_chat_browser_copy_link),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.share,
                    child: Text(l10n.share),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.openExternal,
                    child: Text(l10n.group_chat_browser_open_external),
                  ),
                ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: SizedBox(
            height: 2,
            child:
                _progress < 100
                    ? LinearProgressIndicator(
                      value: _progress / 100,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: AppColors.blue,
                    )
                    : null,
          ),
        ),
      ),
      body:
          _failed
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.group_chat_browser_load_failed,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondary),
                  ),
                ),
              )
              : WebViewWidget(controller: _controller),
      bottomNavigationBar: Material(
        color: chrome,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l10n.group_chat_browser_back,
                  icon: Icon(
                    AppAssets.arrowLeft,
                    color: _canGoBack ? primary : disabled,
                  ),
                  onPressed: _canGoBack ? () => _controller.goBack() : null,
                ),
                IconButton(
                  tooltip: l10n.group_chat_browser_forward,
                  icon: Icon(
                    AppAssets.arrowRight,
                    color: _canGoForward ? primary : disabled,
                  ),
                  onPressed:
                      _canGoForward ? () => _controller.goForward() : null,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openExternal,
                  icon: Icon(AppAssets.arrowSquareOut, size: 20, color: primary),
                  label: Text(
                    l10n.group_chat_browser_open_external,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

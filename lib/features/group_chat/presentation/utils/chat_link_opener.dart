import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/core/config/router/app_router.dart';
import 'package:flutter_pecha/core/deep_linking/app_links_deep_link_service.dart';
import 'package:flutter_pecha/core/utils/url_opener.dart';
import 'package:flutter_pecha/features/group_chat/presentation/screens/chat_web_view_screen.dart';

/// Opens a link tapped in chat. A first-party `webuddhist.com/open/...` link
/// goes to its screen in the app; other web links open in the chat's own
/// browser; anything else (mailto:, tel:) goes to its app.
Future<bool> openChatLink(String url, {NavigatorState? navigator}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;
  if (AppLinksDeepLinkService.instance.openInApp(uri)) return true;

  final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
  final nav = navigator ?? rootNavigatorKey.currentState;
  if (isWeb && nav != null) {
    await showChatWebView(nav, uri);
    return true;
  }
  return openUrl(url);
}

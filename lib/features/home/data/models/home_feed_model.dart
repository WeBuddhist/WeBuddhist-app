import 'package:flutter_pecha/features/connect/data/models/connect_feed_model.dart';
import 'package:flutter_pecha/features/connect/domain/entities/connect_feed_item.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';

/// Reads Home's two feed sources into [HomeFeedPage]s.
///
/// Both serve the v1 Connect feed item, field for field, except that every
/// `group_*` key is named `space_*`. Renaming those keys back lets the Connect
/// parser, and so the Connect cards, serve Home unchanged.
///
/// Only posts and events are kept. `/feed` also mixes in suggestion cards
/// (`suggested_spaces`, `suggested_plans`, `suggested_post`) and may add new
/// types later; Home skips them all.
abstract final class HomeFeedModel {
  static const _shownTypes = {'post', 'event'};

  /// A `GET /api/v2/feed` page: `{items: [{type, id, content}], next_cursor}`.
  static HomeFeedPage parseMemberPage(
    Map<String, dynamic> json, {
    required String language,
  }) {
    final items = <ConnectFeedItem>[];
    for (final entry in _rawItems(json)) {
      if (!_shownTypes.contains(entry['type'])) continue;
      final content = entry['content'];
      if (content is! Map<String, dynamic>) continue;
      final item = _parseItem(content, language: language);
      if (item != null) items.add(item);
    }

    final cursor = json['next_cursor'] as String?;
    return HomeFeedPage(
      items: items,
      next: cursor == null || cursor.isEmpty ? null : HomeFeedCursor(cursor),
    );
  }

  /// A `GET /api/v2/spaces/feed` page: `{items, skip, limit, total}`.
  static HomeFeedPage parsePublicPage(
    Map<String, dynamic> json, {
    required String language,
  }) {
    final raw = _rawItems(json).toList();
    final items = <ConnectFeedItem>[];
    for (final entry in raw) {
      if (!_shownTypes.contains(entry['type'])) continue;
      final item = _parseItem(entry, language: language);
      if (item != null) items.add(item);
    }

    // Counted on what the server sent, so a dropped row doesn't repeat.
    final nextSkip = ((json['skip'] as num?)?.toInt() ?? 0) + raw.length;
    final total = (json['total'] as num?)?.toInt() ?? 0;
    return HomeFeedPage(
      items: items,
      next: raw.isNotEmpty && nextSkip < total ? HomeFeedOffset(nextSkip) : null,
    );
  }

  /// [json] with a `group_*` copy of every `space_*` key, at every depth.
  /// A `group_*` key the server already sent is kept.
  static Map<String, dynamic> withGroupKeys(Map<String, dynamic> json) =>
      _withGroupKeys(json) as Map<String, dynamic>;

  static Object? _withGroupKeys(Object? value) {
    if (value is List) return value.map(_withGroupKeys).toList();
    if (value is! Map) return value;
    final out = <String, dynamic>{
      for (final entry in value.entries)
        '${entry.key}': _withGroupKeys(entry.value),
    };
    for (final key in value.keys.whereType<String>()) {
      if (!key.startsWith('space_')) continue;
      out.putIfAbsent('group_${key.substring(6)}', () => out[key]);
    }
    return out;
  }

  static Iterable<Map<String, dynamic>> _rawItems(Map<String, dynamic> json) =>
      (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();

  static ConnectFeedItem? _parseItem(
    Map<String, dynamic> json, {
    required String language,
  }) {
    final model = ConnectFeedItemModel.fromJson(
      withGroupKeys(json),
      language: language,
    );
    final complete = switch (model.type) {
      ConnectFeedItemType.post => model.post != null,
      ConnectFeedItemType.event => model.event != null,
      ConnectFeedItemType.practice => false,
    };
    return complete ? model.toEntity() : null;
  }
}

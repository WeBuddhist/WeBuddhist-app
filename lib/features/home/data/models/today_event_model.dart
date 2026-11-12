import 'package:flutter_pecha/features/home/domain/entities/today_event.dart';

class TodayEventMetadataModel {
  final String id;
  final String name;
  final String? description;
  final String language;

  TodayEventMetadataModel({
    required this.id,
    required this.name,
    this.description,
    required this.language,
  });

  factory TodayEventMetadataModel.fromJson(Map<String, dynamic> json) {
    return TodayEventMetadataModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      language: (json['language'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'language': language,
    };
  }
}

class TodayEventModel {
  final String id;

  /// One entry per translation. The API sends a list, older responses and
  /// cached entries a single object; both parse into this.
  final List<TodayEventMetadataModel> metadata;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timezone;
  final String? startTime;
  final String? endTime;
  final String? groupAvatarUrl;

  TodayEventModel({
    required this.id,
    required this.metadata,
    this.startDate,
    this.endDate,
    this.timezone,
    this.startTime,
    this.endTime,
    this.groupAvatarUrl,
  });

  factory TodayEventModel.fromJson(Map<String, dynamic> json) {
    return TodayEventModel(
      id: (json['id'] as String?) ?? '',
      metadata: _parseMetadata(json['metadata']),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      timezone: json['timezone'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      groupAvatarUrl: json['group_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'metadata': [for (final m in metadata) m.toJson()],
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'timezone': timezone,
      'start_time': startTime,
      'end_time': endTime,
      'group_avatar_url': groupAvatarUrl,
    };
  }

  /// [language] is the content language (`en`, `bo`, ...). Without a
  /// translation in it, the event keeps its name in another language rather
  /// than showing blank.
  TodayEvent toEntity({String? language}) {
    final chosen = metadataFor(language);
    return TodayEvent(
      id: id,
      name: chosen?.name ?? '',
      description: chosen?.description,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
      startTime: startTime,
      endTime: endTime,
      groupAvatarUrl: groupAvatarUrl,
    );
  }

  /// The named translation in [language], else English, else the first one
  /// with a name. Null when no translation has a name.
  TodayEventMetadataModel? metadataFor(String? language) {
    final named = metadata.where((m) => m.name.trim().isNotEmpty).toList();
    if (named.isEmpty) return null;
    TodayEventMetadataModel? inLanguage(String code) {
      final wanted = code.trim().toUpperCase();
      for (final m in named) {
        if (m.language.trim().toUpperCase() == wanted) return m;
      }
      return null;
    }

    return (language == null ? null : inLanguage(language)) ??
        inLanguage('EN') ??
        named.first;
  }

  static List<TodayEventMetadataModel> _parseMetadata(Object? value) {
    if (value is Map) {
      return [
        TodayEventMetadataModel.fromJson(Map<String, dynamic>.from(value)),
      ];
    }
    if (value is List) {
      return [
        for (final item in value)
          if (item is Map)
            TodayEventMetadataModel.fromJson(Map<String, dynamic>.from(item)),
      ];
    }
    return const [];
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

class TodayEventsResponseModel {
  final List<TodayEventModel> events;

  TodayEventsResponseModel({required this.events});

  factory TodayEventsResponseModel.fromJson(Map<String, dynamic> json) {
    final eventsJson = json['events'] as List<dynamic>? ?? const [];
    return TodayEventsResponseModel(
      events:
          eventsJson
              .map(
                (event) =>
                    TodayEventModel.fromJson(event as Map<String, dynamic>),
              )
              .toList(),
    );
  }

  List<TodayEvent> toEntities({String? language}) =>
      events.map((event) => event.toEntity(language: language)).toList();
}

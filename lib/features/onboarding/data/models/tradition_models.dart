class TraditionPath {
  const TraditionPath({
    required this.code,
    required this.title,
    required this.description,
  });

  final String code;
  final String title;
  final String description;

  factory TraditionPath.fromJson(String code, Map<String, dynamic> json) {
    return TraditionPath(
      code: code,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class UserTradition {
  const UserTradition({
    required this.id,
    required this.traditionCode,
    required this.traditionName,
  });

  final String id;
  final String traditionCode;
  final String traditionName;

  factory UserTradition.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final traditionCode = json['tradition_code'];
    if (id is! String || id.isEmpty) {
      throw FormatException('UserTradition missing id', json);
    }
    if (traditionCode is! String || traditionCode.isEmpty) {
      throw FormatException('UserTradition missing tradition_code', json);
    }
    return UserTradition(
      id: id,
      traditionCode: traditionCode,
      traditionName: json['tradition_name'] as String? ?? '',
    );
  }
}

class SaveTraditionRequest {
  const SaveTraditionRequest({required this.traditionCode});

  final String traditionCode;

  Map<String, dynamic> toJson() => {'tradition_code': traditionCode};
}

const traditionPathOrder = ['pali', 'chinese', 'tibetan'];

/// A tradition from the public catalogue, `GET /traditions`.
class Tradition {
  const Tradition({
    required this.code,
    required this.name,
    this.regions = const [],
    this.libraryTagId,
  });

  final String code;
  final String name;
  final List<String> regions;

  /// Library tag that marks this tradition's texts; null until the CMS sets
  /// it, in which case the tradition cannot filter the library.
  final String? libraryTagId;

  factory Tradition.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    if (code is! String || code.isEmpty) {
      throw FormatException('Tradition missing code', json);
    }
    final tagId = json['library_tag_id'];
    return Tradition(
      code: code,
      name: json['name'] as String? ?? '',
      regions: (json['regions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      libraryTagId: tagId is String && tagId.isNotEmpty ? tagId : null,
    );
  }
}

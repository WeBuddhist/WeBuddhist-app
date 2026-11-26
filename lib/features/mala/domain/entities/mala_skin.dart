import 'package:equatable/equatable.dart';

/// A bead skin from `GET /mala-skins`, offered in the Bead style sheet.
class MalaSkin extends Equatable {
  const MalaSkin({
    required this.id,
    required this.name,
    required this.url,
    this.isDefault = false,
  });

  final String id;

  /// As sent by the server, e.g. `bodhi_seed` or `Dark Blue`.
  final String name;

  /// Presigned and expiring, so never stored.
  final String url;

  /// The server's default skin.
  final bool isDefault;

  /// [name] for display: underscores become spaces and the first letter is
  /// capitalised (`bodhi_seed` → `Bodhi seed`).
  String get displayName {
    final spaced = name.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  List<Object?> get props => [id, name, url, isDefault];
}

import 'package:dio/dio.dart';

/// `POST /text-requests`: asks the team for a text a search did not find.
/// Needs a signed-in user; the server allows 10 per user per rolling day
/// and answers `429` past that. Errors propagate for the repository to map.
class TextRequestsRemoteDatasource {
  TextRequestsRemoteDatasource({required this.dio});

  final Dio dio;

  Future<void> create({required String query, String? language}) async {
    final lang = language?.trim() ?? '';
    await dio.post(
      '/text-requests',
      data: {'query': query.trim(), if (lang.isNotEmpty) 'language': lang},
    );
  }
}

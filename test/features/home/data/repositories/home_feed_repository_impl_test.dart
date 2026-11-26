import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_feed_remote_datasource.dart';
import 'package:flutter_pecha/features/home/data/repositories/home_feed_repository_impl.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records which feed was read and with what; throws [error] when set.
class _FakeDatasource extends HomeFeedRemoteDatasource {
  _FakeDatasource() : super(dio: Dio());

  final calls = <String>[];
  Object? error;

  @override
  Future<HomeFeedPage> fetchMemberFeed({
    required String language,
    String? cursor,
    int limit = HomeFeedRemoteDatasource.pageSize,
  }) async {
    calls.add('member:$language:$cursor');
    if (error case final e?) throw e;
    return const HomeFeedPage(items: [], next: HomeFeedCursor('c2'));
  }

  @override
  Future<HomeFeedPage> fetchPublicFeed({
    required String language,
    int skip = 0,
    int limit = HomeFeedRemoteDatasource.pageSize,
  }) async {
    calls.add('public:$language:$skip');
    if (error case final e?) throw e;
    return const HomeFeedPage(items: [], next: HomeFeedOffset(20));
  }
}

void main() {
  late _FakeDatasource remote;
  late HomeFeedRepositoryImpl repository;

  setUp(() {
    remote = _FakeDatasource();
    repository = HomeFeedRepositoryImpl(remote: remote);
  });

  test('members page /feed by cursor', () async {
    final first = await repository.getFeed(signedIn: true, language: 'en');
    await repository.getFeed(
      signedIn: true,
      language: 'en',
      after: const HomeFeedCursor('c2'),
    );

    expect(remote.calls, ['member:en:null', 'member:en:c2']);
    expect(first.getRight().toNullable()!.next, const HomeFeedCursor('c2'));
  });

  test('guests page the public feed by offset', () async {
    await repository.getFeed(signedIn: false, language: 'zh');
    await repository.getFeed(
      signedIn: false,
      language: 'zh',
      after: const HomeFeedOffset(20),
    );

    expect(remote.calls, ['public:zh:0', 'public:zh:20']);
  });

  test("a token from the other audience reads the first page", () async {
    await repository.getFeed(
      signedIn: true,
      language: 'en',
      after: const HomeFeedOffset(20),
    );
    await repository.getFeed(
      signedIn: false,
      language: 'en',
      after: const HomeFeedCursor('c2'),
    );

    expect(remote.calls, ['member:en:null', 'public:en:0']);
  });

  test('failures map to their Failure, also inside a DioException', () async {
    remote.error = const AuthenticationException('Not authenticated');
    final auth = await repository.getFeed(signedIn: true, language: 'en');
    expect(
      auth.getLeft().toNullable(),
      isA<AuthenticationFailure>().having(
        (f) => f.message,
        'message',
        'getFeed: Not authenticated',
      ),
    );

    remote.error = DioException(
      requestOptions: RequestOptions(),
      error: const NetworkException('offline'),
    );
    final network = await repository.getFeed(signedIn: false, language: 'en');
    expect(network.getLeft().toNullable(), isA<NetworkFailure>());
  });
}

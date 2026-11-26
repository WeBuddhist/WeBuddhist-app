import 'dart:async';

import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_local_datasource.dart';
import 'package:flutter_pecha/features/home/data/models/verse_of_day_model.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';
import 'package:flutter_pecha/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_pecha/features/home/presentation/providers/use_case_providers.dart';
import 'package:flutter_pecha/features/home/presentation/providers/verse_of_day_provider.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/user_tradition_codes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Codes start as [initial]; `null` keeps them loading until [set].
class _FakeCodes extends UserTraditionCodesNotifier {
  _FakeCodes(this.initial);

  final List<String>? initial;

  @override
  FutureOr<List<String>> build() =>
      initial ?? Completer<List<String>>().future;

  void set(List<String> codes) => state = AsyncData(codes);
}

class _EmptyLocal extends HomeLocalDatasource {
  @override
  List<VerseOfDayModel>? readRecentVerses(
    String language, {
    String? tradition,
  }) => null;
}

class _FakeRepository implements VerseOfDayRepositoryInterface {
  final watchedTraditions = <String?>[];

  @override
  Stream<Either<Failure, List<VerseOfDay>>> watchRecentVerses({
    required String language,
    String? tradition,
  }) {
    watchedTraditions.add(tradition);
    return Stream.value(const Right([]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepository repository;
  late _FakeCodes codes;

  ProviderContainer build(List<String>? traditionCodes) {
    repository = _FakeRepository();
    codes = _FakeCodes(traditionCodes);
    final container = ProviderContainer(
      overrides: [
        contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
        homeLocalDatasourceProvider.overrideWithValue(_EmptyLocal()),
        verseOfDayDomainRepositoryProvider.overrideWithValue(repository),
        userTraditionCodesProvider.overrideWith(() => codes),
      ],
    );
    addTearDown(container.dispose);
    container.listen(recentVersesOfDayProvider, (_, __) {});
    return container;
  }

  test('asks for the highest-priority tradition the user follows', () async {
    build(const ['chinese', 'tibetan']);
    await pumpEventQueue();
    expect(repository.watchedTraditions, ['tibetan']);
  });

  test('no traditions asks for the All traditions week', () async {
    build(const []);
    await pumpEventQueue();
    expect(repository.watchedTraditions, [null]);
  });

  test('waits for the traditions, then re-fetches when they change', () async {
    build(null);
    await pumpEventQueue();
    expect(repository.watchedTraditions, isEmpty);

    codes.set(const ['chinese']);
    await pumpEventQueue();
    expect(repository.watchedTraditions, ['chinese']);

    codes.set(const ['chinese', 'pali']);
    await pumpEventQueue();
    expect(repository.watchedTraditions, ['chinese', 'pali']);
  });
}

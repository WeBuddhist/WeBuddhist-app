import 'dart:async';

import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_spaces_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A container whose space feeds never answer (or failed), as a slow or
/// broken network leaves them.
ProviderContainer _container(AuthState auth, {bool booksFailed = false}) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith((ref) => _Auth(auth)),
      practiceSpacePracticesProvider.overrideWith(
        (ref, query) => Future.value(const Right([])),
      ),
      spaceChantBooksProvider.overrideWith(
        (ref) =>
            booksFailed
                ? Future.value(
                  const Left<Failure, SpaceChantBooks>(ServerFailure('down')),
                )
                : Completer<Either<Failure, SpaceChantBooks>>().future,
      ),
    ],
  );
}

void main() {
  const guest = AuthState(isLoggedIn: true, isGuest: true);
  const signedOut = AuthState(isLoggedIn: false);
  const member = AuthState(isLoggedIn: true);

  test('a guest never waits on the joined-space rows', () async {
    for (final auth in [guest, signedOut]) {
      final container = _container(auth);
      addTearDown(container.dispose);
      expect(
        container.read(practiceJoinedSpaceContentLoadingProvider),
        isFalse,
      );
      expect(container.read(practiceJoinedSpaceContentFailedProvider), isFalse);
      expect(container.read(practiceHasJoinedSpaceContentProvider), isFalse);
    }
  });

  test('a failed public feed is not a failed joined row for a guest', () async {
    final container = _container(guest, booksFailed: true);
    addTearDown(container.dispose);
    await container.read(spaceChantBooksProvider.future);
    expect(container.read(practiceJoinedSpaceContentFailedProvider), isFalse);
  });

  test('a member waits while the chant books load', () async {
    final container = _container(member);
    addTearDown(container.dispose);
    expect(container.read(practiceJoinedSpaceContentLoadingProvider), isTrue);
  });
}

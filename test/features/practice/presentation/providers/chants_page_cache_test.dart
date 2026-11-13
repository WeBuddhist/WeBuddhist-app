import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  group('cacheSuccessFor', () {
    late int loads;
    late Either<Failure, int> next;
    late AutoDisposeFutureProvider<Either<Failure, int>> provider;

    setUp(() {
      loads = 0;
      next = const Right(1);
      provider = FutureProvider.autoDispose<Either<Failure, int>>((ref) {
        loads++;
        return ref.cacheSuccessFor(
          Future.value(next),
          const Duration(minutes: 5),
        );
      });
    });

    Future<void> visit(ProviderContainer container) async {
      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      sub.close();
      // Let autoDispose run if nothing keeps the provider.
      await Future<void>.delayed(Duration.zero);
    }

    test('a success is kept after the last listener leaves', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await visit(container);
      await visit(container);
      expect(loads, 1);
    });

    test('a failure is read again on the next visit', () async {
      next = const Left(ServerFailure('down'));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await visit(container);
      await visit(container);
      expect(loads, 2);
    });

    test('an invalidate still reads again', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await visit(container);
      container.invalidate(provider);
      await visit(container);
      expect(loads, 2);
    });

    test('a success that cacheIf rejects is read again', () async {
      provider = FutureProvider.autoDispose<Either<Failure, int>>((ref) {
        loads++;
        return ref.cacheSuccessFor(
          Future.value(next),
          const Duration(minutes: 5),
          // Odd values stand for a partial read.
          cacheIf: (value) => value.isEven,
        );
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await visit(container);
      await visit(container);
      expect(loads, 2);

      next = const Right(2);
      await visit(container);
      await visit(container);
      expect(loads, 3);
    });
  });
}

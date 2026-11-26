import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_pecha/shared/domain/base_classes/usecase.dart';
import 'package:fpdart/fpdart.dart';

/// Initialize auth use case.
///
/// Prepares the auth system. Returns true when that signed out a session left
/// by an earlier Auth0 build, so the caller can drop that account's identity.
class InitializeAuthUseCase extends UseCase<bool, NoParams> {
  final AuthRepository _repository;

  InitializeAuthUseCase(this._repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    final result = await _repository.initialize();
    return result.map((_) => _repository.takeLegacySessionRemoved());
  }
}

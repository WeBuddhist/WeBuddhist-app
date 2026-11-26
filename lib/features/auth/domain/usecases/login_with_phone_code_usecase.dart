import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/domain/entities/auth_credentials.dart';
import 'package:flutter_pecha/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_pecha/shared/domain/base_classes/usecase.dart';
import 'package:fpdart/fpdart.dart';

/// Finishes a phone sign-in with the code from the SMS.
class LoginWithPhoneCodeUseCase
    extends UseCase<AuthCredentials, LoginWithPhoneCodeParams> {
  final AuthRepository _repository;

  LoginWithPhoneCodeUseCase(this._repository);

  @override
  Future<Either<Failure, AuthCredentials>> call(
    LoginWithPhoneCodeParams params,
  ) {
    return _repository.loginWithPhoneCode(
      verificationId: params.verificationId,
      smsCode: params.smsCode,
    );
  }
}

class LoginWithPhoneCodeParams {
  const LoginWithPhoneCodeParams({
    required this.verificationId,
    required this.smsCode,
  });

  final String verificationId;
  final String smsCode;
}

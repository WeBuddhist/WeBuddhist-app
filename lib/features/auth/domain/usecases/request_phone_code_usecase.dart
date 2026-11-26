import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/domain/entities/phone_code_start.dart';
import 'package:flutter_pecha/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_pecha/shared/domain/base_classes/usecase.dart';
import 'package:fpdart/fpdart.dart';

/// Sends an SMS sign-in code to a phone number.
class RequestPhoneCodeUseCase
    extends UseCase<PhoneCodeStart, RequestPhoneCodeParams> {
  final AuthRepository _repository;

  RequestPhoneCodeUseCase(this._repository);

  @override
  Future<Either<Failure, PhoneCodeStart>> call(RequestPhoneCodeParams params) {
    return _repository.requestPhoneCode(
      params.phoneNumber,
      resendToken: params.resendToken,
    );
  }
}

class RequestPhoneCodeParams {
  const RequestPhoneCodeParams({required this.phoneNumber, this.resendToken});

  /// E.164, e.g. `+919876543210`.
  final String phoneNumber;

  /// From the previous request, when asking for the code again.
  final int? resendToken;
}

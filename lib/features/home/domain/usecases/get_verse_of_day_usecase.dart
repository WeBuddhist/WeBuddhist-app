import 'package:fpdart/fpdart.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';
import 'package:flutter_pecha/shared/domain/base_classes/usecase.dart';

class GetVerseOfDayUseCase extends UseCase<VerseOfDay, GetVerseOfDayParams> {
  final Future<Either<Failure, VerseOfDay>> Function({
    required String language,
    String? tradition,
  })
  _getVerseOfDay;

  GetVerseOfDayUseCase(this._getVerseOfDay);

  @override
  Future<Either<Failure, VerseOfDay>> call(GetVerseOfDayParams params) async {
    return await _getVerseOfDay(
      language: params.language,
      tradition: params.tradition,
    );
  }
}

class GetVerseOfDayParams {
  final String language;

  /// See `verseOfDayTradition`; null is the All traditions verse.
  final String? tradition;

  const GetVerseOfDayParams({required this.language, this.tradition});
}

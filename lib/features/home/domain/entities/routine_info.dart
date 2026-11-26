import 'package:equatable/equatable.dart';

class RoutineInfo extends Equatable {
  final int seriesCount;
  final int recitationCount;

  const RoutineInfo({
    required this.seriesCount,
    required this.recitationCount,
  });

  /// Plans and chants together: the "N sessions" on Home's My practices.
  int get totalCount => seriesCount + recitationCount;

  @override
  List<Object?> get props => [seriesCount, recitationCount];
}

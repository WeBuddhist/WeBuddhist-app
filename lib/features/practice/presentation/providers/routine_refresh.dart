import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/home/presentation/providers/routine_info_provider.dart';
import 'package:flutter_pecha/features/notifications/application/notification_sync_engine.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/routine_api_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/routine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('RoutineRefresh');

/// Reloads the routine after the server changed it without a routine edit,
/// e.g. deleting a saved timer removes its sessions (and any block left
/// empty) from the routine.
///
/// Refreshes both copies: the server routine the screens show, and the local
/// one that schedules reminders. Everything is read from [ref] up front, so
/// the caller may be disposed (a sheet that pops) while this finishes.
Future<void> refreshRoutineFromServer(WidgetRef ref) async {
  ref.invalidate(userRoutineProvider);
  ref.invalidate(routineInfoFutureProvider);

  final getUserRoutine = ref.read(getUserRoutineUseCaseProvider);
  final language = ref.read(contentLanguageProvider);
  final routineNotifier = ref.read(routineProvider.notifier);
  final syncEngine = ref.read(notificationSyncEngineProvider);

  try {
    final result = await getUserRoutine(language: language);
    await result.fold(
      // Offline: keep the local routine rather than wipe a valid schedule.
      (failure) async =>
          _logger.warning('Routine refresh failed: $failure — keeping local'),
      (serverRoutine) async {
        await routineNotifier.whenLoaded;
        await routineNotifier.hydrateFromServer(
          serverRoutine ?? const RoutineData(),
        );
        await syncEngine.sync(trigger: SyncTrigger.routineSaved);
      },
    );
  } catch (e) {
    _logger.warning('Routine refresh threw: $e — keeping local');
  }
}

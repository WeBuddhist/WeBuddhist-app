import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/storage/preferences_service.dart'
    show SharedPreferencesService;
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/storage/storage_service.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/calendar/domain/models/calendar_type.dart';
import 'package:flutter_pecha/features/calendar/presentation/providers/tibetan_calendar_providers.dart';
import 'package:flutter_pecha/features/more/presentation/providers/user_traditions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('CalendarTypeProviders');

// ============ The viewer's calendar ============

/// The calendar type the calendar is shown in, kept on this device. Read
/// synchronously when preferences are already loaded, so the first frame asks
/// the backend for the right calendar.
class SelectedCalendarTypeNotifier extends StateNotifier<String> {
  SelectedCalendarTypeNotifier(this._storage)
    : super(_sanitize(_readSync(_storage))) {
    if (_readSync(_storage) == null) _load();
  }

  final StorageService _storage;

  /// Set once the viewer picks, so a slow first read can't undo the pick.
  bool _picked = false;

  static String? _readSync(StorageService storage) =>
      storage is SharedPreferencesService
          ? storage.getSync<String>(StorageKeys.calendarType)
          : null;

  /// A stored type the app no longer supports falls back to the default.
  static String _sanitize(String? code) =>
      code != null && supportedCalendarTypes.contains(code)
          ? code
          : defaultCalendarType;

  Future<void> _load() async {
    try {
      final stored = await _storage.get<String>(StorageKeys.calendarType);
      if (mounted && !_picked && stored != null) state = _sanitize(stored);
    } catch (e, stackTrace) {
      _logger.error('Failed to read the calendar type', e, stackTrace);
    }
  }

  Future<void> select(String code) async {
    if (!supportedCalendarTypes.contains(code)) return;
    _picked = true;
    if (state == code) return;
    state = code;
    try {
      await _storage.set<String>(StorageKeys.calendarType, code);
    } catch (e, stackTrace) {
      _logger.error('Failed to save the calendar type', e, stackTrace);
    }
  }
}

final selectedCalendarTypeProvider =
    StateNotifierProvider<SelectedCalendarTypeNotifier, String>(
      (ref) => SelectedCalendarTypeNotifier(ref.watch(storageServiceProvider)),
    );

// ============ What can be picked ============

/// Every calendar the backend lists, by tradition (`GET /calendar/types`).
/// Falls back to the Tibetan calendars when it can't be reached, so the picker
/// always opens.
final calendarTraditionsProvider = FutureProvider<List<CalendarTradition>>((
  ref,
) async {
  try {
    final traditions =
        await ref.watch(calendarRemoteDatasourceProvider).fetchTypes();
    return traditions.isEmpty ? fallbackCalendarTraditions : traditions;
  } catch (e, stackTrace) {
    _logger.error('Failed to load calendar types', e, stackTrace);
    return fallbackCalendarTraditions;
  }
});

/// The traditions and calendars the "Choose calendar" sheet lists: the
/// supported calendars of a signed-in viewer's own traditions (see
/// [calendarChoices]); every supported calendar for guests, or while their
/// traditions load.
final calendarTypeChoicesProvider =
    Provider.autoDispose<AsyncValue<List<CalendarTradition>>>((ref) {
      final selected = ref.watch(selectedCalendarTypeProvider);
      final auth = ref.watch(authProvider);
      final signedIn = auth.isLoggedIn && !auth.isGuest;
      final userTraditions =
          signedIn
              ? ref
                  .watch(userTraditionsProvider)
                  .valueOrNull
                  ?.map((t) => t.traditionCode)
                  .toSet()
              : null;
      return ref
          .watch(calendarTraditionsProvider)
          .whenData(
            (all) => calendarChoices(
              all,
              selected: selected,
              userTraditions: userTraditions,
            ),
          );
    });

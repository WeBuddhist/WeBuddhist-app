import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/app_open_analytics.dart';
import 'package:flutter_pecha/core/analytics/clarity_screen_observer.dart';
import 'package:flutter_pecha/core/analytics/clarity_screen_tracker.dart';
import 'package:flutter_pecha/core/analytics/foreground_gate.dart';
import 'package:flutter_pecha/core/analytics/no_op_analytics_service.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/env.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

final _logger = AppLogger('PostHogAnalytics');

/// Property keys blanked before an event leaves the device.
const List<String> _redactedKeys = [
  'email',
  'id_token',
  'access_token',
  'phone',
  'name',
  'username',
];

/// PostHog-backed analytics. Initialized manually after dotenv is loaded.
class PostHogAnalyticsService
    implements AnalyticsService, PersonProfileAnalytics {
  PostHogAnalyticsService._();

  static PostHogAnalyticsService? _instance;
  static PostHogAnalyticsService get instance =>
      _instance ??= PostHogAnalyticsService._();

  bool _isInitialized = false;

  /// False until [initialize] has set the SDK up; every call before that is
  /// dropped.
  @override
  bool get acceptsPersonProperties => _isInitialized;

  static AnalyticsService create() {
    if (!Env.posthogEnabled) {
      _logger.info('PostHog disabled — using no-op analytics');
      return const NoOpAnalyticsService();
    }
    return PostHogAnalyticsService.instance;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized || !Env.posthogEnabled) return;

    final String? apiKey = Env.posthogApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      _logger.warning('POSTHOG_API_KEY missing — analytics disabled');
      return;
    }

    // Before setup: from setup on, the SDK's stored version is this build's,
    // which would hide whether this device had an earlier install.
    final AppOpenStore openStore = SharedPreferencesAppOpenStore();
    await AppOpenAnalytics.migrate(
      store: openStore,
      probe: () => readLegacyInstall(posthogToken: apiKey),
    );

    final PostHogConfig config = PostHogConfig(apiKey);
    config.host = Env.posthogHost;
    config.debug = Env.isDebug;
    config.personProfiles = PostHogPersonProfiles.identifiedOnly;
    config.beforeSend = [_redactPii];
    // Our own push_notification_opened already counts every push tap.
    config.capturePushNotificationOpened = false;
    // The SDKs send these at setup, so audio_service's headless engine and
    // iOS background launches counted as installs and opens. AppOpenAnalytics
    // sends them only once the UI is shown.
    config.captureApplicationLifecycleEvents = false;

    if (kReleaseMode) {
      config.sessionReplay = true;
      config.sessionReplayConfig.maskAllTexts = true;
      // Avatars, banners and user uploads must not reach replay.
      config.sessionReplayConfig.maskAllImages = true;
    }

    await Posthog().setup(config);

    // Before registering: setSuperProperties is a no-op until this is set.
    _isInitialized = true;
    await _registerDefaultSuperProperties();

    AppOpenAnalytics(
      store: openStore,
      capture: _captureLifecycleEvent,
      onFirstOpen: _foregroundGate.open,
    ).attach();
    _logger.info('PostHog initialized for ${Env.appFlavor}');
  }

  /// Holds events, identifies and screen views until the UI is first shown,
  /// so a headless start sends nothing. Super properties and reset() only
  /// change local state and stay immediate.
  final ForegroundGate _foregroundGate = ForegroundGate();

  @override
  Future<void> identify({
    required String userId,
    Map<String, Object?>? properties,
  }) async {
    if (!_isInitialized) return;

    final Map<String, Object>? setOnce = setOnceProperties(
      properties: properties,
      appVersion: _appVersion,
    );
    await _foregroundGate.run(
      () => Posthog().identify(
        userId: userId,
        userProperties: _sanitizeProperties(properties),
        userPropertiesSetOnce: setOnce,
      ),
    );
  }

  /// `first_app_version`, sent only with a real login. Only a login passes
  /// person [properties]; a restored session on a cold start passes none, and
  /// sending it there would make PostHog record a profile update every launch.
  @visibleForTesting
  static Map<String, Object>? setOnceProperties({
    required Map<String, Object?>? properties,
    required String? appVersion,
  }) {
    if (properties == null || appVersion == null) return null;
    return {AnalyticsProperties.firstAppVersion: appVersion};
  }

  @override
  Future<void> reset() async {
    if (!_isInitialized) return;

    // Anything held back belonged to the identity being dropped.
    _foregroundGate.discardPending();
    await Posthog().reset();
    await _registerDefaultSuperProperties();
    // The device's languages don't change with the account.
    await setSuperProperties(Map.of(_languageProperties));
  }

  @override
  Future<void> track(String event, {Map<String, Object?>? properties}) async {
    if (!_isInitialized) return;

    final Map<String, Object>? sanitized = _sanitizeProperties(
      withSanghaGroup(properties),
    );
    await _foregroundGate.run(
      () => Posthog().capture(eventName: event, properties: sanitized),
    );
  }

  /// The app version, once read at start-up; null in tests.
  String? _appVersion;

  /// The last UI and content language registered, put back after [reset].
  final Map<String, Object> _languageProperties = {};

  @override
  Future<void> setSuperProperties(Map<String, Object?> properties) async {
    if (!_isInitialized) return;

    for (final String key in const [
      AnalyticsProperties.uiLanguage,
      AnalyticsProperties.contentLanguage,
    ]) {
      final Object? value = properties[key];
      if (value != null) _languageProperties[key] = value;
    }

    for (final MapEntry<String, Object?> entry in properties.entries) {
      final Object? value = entry.value;
      if (value != null) {
        await Posthog().register(entry.key, value);
      }
    }
  }

  /// Lifecycle events decide when the gate opens, so they skip it.
  Future<void> _captureLifecycleEvent(
    String event,
    Map<String, Object> properties,
  ) {
    return Posthog().capture(
      eventName: event,
      properties: properties.isEmpty ? null : properties,
    );
  }

  /// Names the screen actually on top across the root and tab navigators,
  /// as Clarity does. PosthogObserver alone skips the unnamed tab shell and
  /// never sees a tab switch, so `$screen_name` kept the last pushed screen
  /// after going back to a tab.
  late final ClarityScreenTracker _screenTracker = ClarityScreenTracker(
    onScreenChanged: _captureScreen,
  );

  @override
  List<NavigatorObserver> get routeObservers => [
    // Kept only for the navigator context PostHog shows surveys in. Screens
    // come from [_screenTracker], so this observer never sends one.
    PosthogObserver(routeFilter: _neverTrack),
    ClarityScreenObserver(_screenTracker),
  ];

  /// Bottom tabs are not routes: main() reports the selected one here, and
  /// the tab shell is then named `tab-<tab>`.
  void setTab(String tab) => _screenTracker.setTab(tab);

  /// Sends one `$screen` per change of the visible screen. Until the UI is
  /// first shown they wait on the gate, like events.
  void _captureScreen(String screenName) {
    if (!_isInitialized) return;
    unawaited(
      _foregroundGate.run(() => Posthog().screen(screenName: screenName)),
    );
  }

  static bool _neverTrack(Route<dynamic>? route) => false;

  /// Session replay only records inside [PostHogWidget]; it must mount after
  /// [initialize], which main() guarantees. Returns [child] untouched when
  /// PostHog is off.
  static Widget wrap(Widget child) {
    if (!Env.posthogEnabled) return child;
    return PostHogWidget(child: child);
  }

  Future<void> _registerDefaultSuperProperties() async {
    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      // Unavailable in test environments — version properties skipped.
    }

    await setSuperProperties({
      'environment': Env.environment,
      'app_flavor': Env.appFlavor,
      'build_mode': buildMode,
      'platform': Platform.operatingSystem,
      if (packageInfo != null) 'app_version': packageInfo.version,
      if (packageInfo != null) 'build_number': packageInfo.buildNumber,
    });
    _appVersion = packageInfo?.version;
  }

  /// `debug` or `profile` when the app runs from a developer's machine
  /// (`flutter run`); store and TestFlight builds are always `release`. Sent
  /// as `build_mode` so local runs can be filtered out of real-user data.
  @visibleForTesting
  static String get buildMode {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  /// An event with a `group_id` belongs to that sangha. PostHog reads
  /// `$groups` per event, so nothing lingers once the user leaves the group.
  static Map<String, Object?>? withSanghaGroup(
    Map<String, Object?>? properties,
  ) {
    final Object? groupId = properties?[AnalyticsProperties.groupId];
    if (groupId is! String || groupId.isEmpty) return properties;
    return {
      ...properties!,
      AnalyticsProperties.groups: {AnalyticsGroupTypes.sangha: groupId},
    };
  }

  static Map<String, Object>? _sanitizeProperties(
    Map<String, Object?>? properties,
  ) {
    if (properties == null || properties.isEmpty) {
      return null;
    }

    final Map<String, Object> sanitized = <String, Object>{};
    for (final MapEntry<String, Object?> entry in properties.entries) {
      final Object? value = entry.value;
      if (value != null) {
        sanitized[entry.key] = value;
      }
    }
    return sanitized.isEmpty ? null : sanitized;
  }

  static PostHogEvent? _redactPii(PostHogEvent event) {
    final Map<String, Object>? properties = event.properties;
    if (properties == null) {
      return event;
    }

    for (final String key in _redactedKeys) {
      if (properties.containsKey(key)) {
        properties[key] = '***';
      }
    }

    return event;
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/app_open_analytics.dart';
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
class PostHogAnalyticsService implements AnalyticsService {
  PostHogAnalyticsService._();

  static PostHogAnalyticsService? _instance;
  static PostHogAnalyticsService get instance =>
      _instance ??= PostHogAnalyticsService._();

  bool _isInitialized = false;

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

    await _foregroundGate.run(
      () => Posthog().identify(
        userId: userId,
        userProperties: _sanitizeProperties(properties),
      ),
    );
  }

  @override
  Future<void> reset() async {
    if (!_isInitialized) return;

    // Anything held back belonged to the identity being dropped.
    _foregroundGate.discardPending();
    await Posthog().reset();
    await _registerDefaultSuperProperties();
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

  @override
  Future<void> setSuperProperties(Map<String, Object?> properties) async {
    if (!_isInitialized) return;

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

  @override
  List<NavigatorObserver> get routeObservers => [
    PosthogObserver(routeFilter: _screenRouteFilter),
  ];

  /// While the UI has not been shown, PosthogObserver would still send
  /// screens: it takes a missing lifecycle state, as in audio_service's
  /// headless engine, for the foreground. Those screens are queued on the
  /// gate instead, named as PosthogObserver names them.
  bool _screenRouteFilter(Route<dynamic>? route) {
    if (!defaultPostHogRouteFilter(route)) return false;
    if (_foregroundGate.isOpen) return true;
    final String? name = route?.settings.name;
    if (_isInitialized && name != null && name.trim().isNotEmpty) {
      final String screenName = name == '/' ? "root ('/')" : name;
      unawaited(
        _foregroundGate.run(() => Posthog().screen(screenName: screenName)),
      );
    }
    return false;
  }

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
      'platform': Platform.operatingSystem,
      if (packageInfo != null) 'app_version': packageInfo.version,
      if (packageInfo != null) 'build_number': packageInfo.buildNumber,
    });
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

import 'package:flutter/widgets.dart';

/// Product analytics abstraction. Features depend on this interface, not PostHog.
abstract class AnalyticsService {
  Future<void> initialize();

  Future<void> identify({
    required String userId,
    Map<String, Object?>? properties,
  });

  Future<void> reset();

  Future<void> track(String event, {Map<String, Object?>? properties});

  Future<void> setSuperProperties(Map<String, Object?> properties);


  /// Fresh observers for one navigator; wired into the root and shell
  /// navigators so screen transitions are tracked.
  List<NavigatorObserver> get routeObservers;
}

/// A backend that keeps person profiles and can say whether it is taking
/// them right now. PostHog is one; Clarity keeps none.
abstract interface class PersonProfileAnalytics {
  /// False while a person property sent now would be dropped: the backend is
  /// switched off in this build, or did not start.
  bool get acceptsPersonProperties;
}

extension AnalyticsPersonProfiles on AnalyticsService {
  /// Whether a `$set` sent now reaches a person profile. A caller that keeps
  /// a note of what it already sent checks this first, so a value dropped
  /// here is sent again later and not remembered as sent.
  ///
  /// A service that cannot say (a test double) is taken to accept it.
  bool get canStorePersonProperties {
    // Held as an Object so the type test below promotes it: the interface
    // is not a subtype of AnalyticsService.
    final Object service = this;
    return service is! PersonProfileAnalytics ||
        service.acceptsPersonProperties;
  }
}

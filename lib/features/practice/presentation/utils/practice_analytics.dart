import 'dart:math' as math;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product analytics for the routine: one method per tracked action, so the
/// event names and their property keys live in one place. Every call fires
/// and forgets; callers fire after the server confirms, never optimistically.
class PracticeAnalytics {
  const PracticeAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// Tracking-plan key for a routine item type (`item_type`, `session_types`).
  static String itemTypeKey(RoutineItemType type) => switch (type) {
    RoutineItemType.accumulator => 'mala',
    RoutineItemType.groupAccumulator ||
    RoutineItemType.groupRecitationCollection => 'group_practice',
    RoutineItemType.myRecitationCollection => 'recitation_collection',
    _ => type.name,
  };

  /// Signed minutes from a block's scheduled time to [now]; negative before.
  static int minutesFromBlockTime(TimeOfDay time, DateTime now) {
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return now.difference(scheduled).inMinutes;
  }

  /// The user started [item] from the routine card; fired after navigation.
  void routineItemOpened({
    required RoutineItem item,
    required int blockIndex,
    required TimeOfDay blockTime,
    DateTime? now,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.routineItemOpened, {
      AnalyticsProperties.itemType: itemTypeKey(item.type),
      AnalyticsProperties.itemId: item.id,
      AnalyticsProperties.blockIndex: blockIndex,
      AnalyticsProperties.minutesFromBlockTime: minutesFromBlockTime(
        blockTime,
        now ?? DateTime.now(),
      ),
    });
  }

  /// The routine was persisted; [data] is the routine after the save.
  void routineSaved(RoutineData data) {
    final items = [for (final block in data.blocks) ...block.items];
    _analytics.trackInBackground(AnalyticsEvents.routineSaved, {
      AnalyticsProperties.blockCount: data.blocks.length,
      AnalyticsProperties.itemCount: items.length,
      AnalyticsProperties.sessionTypes:
          {for (final item in items) itemTypeKey(item.type)}.toList(),
      AnalyticsProperties.reminderEnabled:
          data.blocks.any((block) => block.notificationEnabled),
      AnalyticsProperties.earliestBlockHour:
          data.blocks.isEmpty
              ? null
              : data.blocks.map((block) => block.time.hour).reduce(math.min),
    });
  }

  /// Saving a routine with a plan the user did not have enrolled them.
  void planEnrolledFromRoutine({
    required String planId,
    required String planName,
    required int totalDays,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.planEnrolled, {
      AnalyticsProperties.planId: planId,
      AnalyticsProperties.planName: planName,
      AnalyticsProperties.totalDays: totalDays,
      AnalyticsProperties.source: 'routine',
    });
  }

  /// A bookmark was saved or removed on the server. [itemType] is the
  /// bookmark type's key, e.g. `text`, `verse`, `group_accumulator`.
  void bookmarkChanged({
    required bool added,
    required String itemType,
    required String itemId,
  }) {
    _analytics.trackInBackground(
      added ? AnalyticsEvents.bookmarkAdded : AnalyticsEvents.bookmarkRemoved,
      {
        AnalyticsProperties.itemType: itemType,
        AnalyticsProperties.itemId: itemId,
      },
    );
  }

  /// The Bookmarks screen opened.
  void bookmarksOpened() {
    _analytics.trackInBackground(AnalyticsEvents.bookmarksOpened, {});
  }

  /// A personal recitation collection was created on the server.
  void collectionCreated({
    required String collectionId,
    required int itemCount,
    required bool hasImage,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.collectionCreated, {
      AnalyticsProperties.collectionId: collectionId,
      AnalyticsProperties.itemCount: itemCount,
      AnalyticsProperties.hasImage: hasImage,
    });
  }

  /// Every change of an edit was saved. Counts only, no names.
  void collectionUpdated({
    required String collectionId,
    required int itemCount,
    required int itemsAdded,
    required int itemsRemoved,
    required bool reordered,
    required bool renamed,
    required bool imageChanged,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.collectionUpdated, {
      AnalyticsProperties.collectionId: collectionId,
      AnalyticsProperties.itemCount: itemCount,
      AnalyticsProperties.itemsAdded: itemsAdded,
      AnalyticsProperties.itemsRemoved: itemsRemoved,
      AnalyticsProperties.reordered: reordered,
      AnalyticsProperties.renamed: renamed,
      AnalyticsProperties.imageChanged: imageChanged,
    });
  }

  /// A personal recitation collection was deleted on the server.
  void collectionDeleted({required String collectionId}) {
    _analytics.trackInBackground(AnalyticsEvents.collectionDeleted, {
      AnalyticsProperties.collectionId: collectionId,
    });
  }

  /// Saving a routine with a series the user did not have enrolled them.
  void seriesEnrolledFromRoutine({required String seriesId}) {
    _analytics.trackInBackground(AnalyticsEvents.seriesEnrolled, {
      AnalyticsProperties.seriesId: seriesId,
      AnalyticsProperties.source: 'routine',
    });
  }
}

final practiceAnalyticsProvider = Provider<PracticeAnalytics>((ref) {
  return PracticeAnalytics(ref.watch(analyticsServiceProvider));
});

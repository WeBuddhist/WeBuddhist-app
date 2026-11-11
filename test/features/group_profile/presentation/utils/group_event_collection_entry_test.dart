import 'dart:async';

import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_event.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/group_profile/domain/repositories/group_profile_repository.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_recitation_completion_service.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_actions.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_collection_entry.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_pecha/features/reader/presentation/providers/reader_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _collectionRef = GroupEventPracticeRef(id: 'c1', name: 'Monday');
const _plan = GroupEventPracticeRef(id: 'p1', name: 'Puja');
const _key = GroupRecitationCollectionKey(groupId: 'g1', collectionId: 'c1');

GroupRecitationCollectionItem _chant(String id, String textId, int order) =>
    GroupRecitationCollectionItem(
      id: id,
      textId: textId,
      title: 'Text $order',
      language: 'en',
      type: 'chant',
      displayOrder: order,
    );

extension on GroupRecitationCollectionItem {
  GroupRecitationCollectionItem copyLanguage(String language) =>
      GroupRecitationCollectionItem(
        id: id,
        textId: textId,
        title: title,
        language: language,
        type: type,
        displayOrder: displayOrder,
      );
}

final _collection = GroupRecitationCollection(
  id: 'c1',
  groupId: 'g1',
  name: '84000: Monday',
  items: [_chant('i1', 't1', 1), _chant('i2', 't2', 2), _chant('i3', 't3', 3)],
);

NavigationContext _context({
  String? liveTextId,
  String? liveSegmentId,
  bool online = false,
  bool readOnly = false,
  Set<String> completed = const {},
}) => groupEventCollectionNavigationContext(
  eventId: 'e1',
  key: _key,
  collection: _collection,
  completionState: GroupRecitationCollectionCompletionState(
    completedChantIds: completed,
  ),
  isOnlineAttendee: online,
  groupName: 'Sangha',
  liveTextId: liveTextId,
  liveSegmentId: liveSegmentId,
  readOnly: readOnly,
);

class _SignedInAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedInAuth() : super(const AuthState(isLoggedIn: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAnalytics implements AnalyticsService {
  final events = <String>[];

  @override
  Future<void> track(String event, {Map<String, Object?>? properties}) async {
    events.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRepository extends Fake implements GroupProfileRepositoryInterface {
  final completedCalls = <String>[];

  /// When set, every completion waits for it, so the answers land together.
  Completer<void>? gate;

  @override
  Future<Either<Failure, Set<String>>> getTodayRecitationCollectionCompletions({
    required String collectionId,
  }) async => const Right({});

  @override
  Future<Either<Failure, void>> completeRecitationCollectionChant({
    required String collectionId,
    required String chantId,
  }) async {
    completedCalls.add(chantId);
    await gate?.future;
    return const Right(null);
  }
}

void main() {
  group('GroupEvent.practiceCollectionId', () {
    test('is the collection when no plan or series is attached', () {
      const event = GroupEvent(
        id: 'e1',
        groupId: 'g1',
        groupRecitationCollection: _collectionRef,
      );
      expect(event.practiceCollectionId, 'c1');
      expect(event.hasPuja, isTrue);
    });

    test('falls back to the bare collection id', () {
      const event = GroupEvent(
        id: 'e1',
        groupId: 'g1',
        groupRecitationCollectionId: 'c9',
      );
      expect(event.practiceCollectionId, 'c9');
    });

    test('a plan or series wins over the collection', () {
      const withPlan = GroupEvent(
        id: 'e1',
        groupId: 'g1',
        plan: _plan,
        groupRecitationCollection: _collectionRef,
      );
      const withSeriesId = GroupEvent(
        id: 'e1',
        groupId: 'g1',
        seriesId: 's1',
        groupRecitationCollection: _collectionRef,
      );
      expect(withPlan.practiceCollectionId, isNull);
      expect(withSeriesId.practiceCollectionId, isNull);
    });

    test('no content leaves the event without a puja', () {
      const event = GroupEvent(id: 'e1', groupId: 'g1');
      expect(event.practiceCollectionId, isNull);
      expect(event.hasPuja, isFalse);
    });

    test('a collection-only event offers the view and practice buttons', () {
      const event = GroupEvent(
        id: 'e1',
        groupId: 'g1',
        eventFormat: 'hybrid',
        groupRecitationCollection: _collectionRef,
      );
      expect(groupEventActionsFor(event, isAttending: false, isPast: false), [
        GroupEventAction.viewInPerson,
        GroupEventAction.viewOnline,
        GroupEventAction.join,
      ]);
      expect(groupEventActionsFor(event, isAttending: true, isPast: false), [
        GroupEventAction.practiceInPerson,
        GroupEventAction.practiceOnline,
      ]);
    });
  });

  group('groupEventCollectionNavigationContext', () {
    test('puts every text on one page, in order', () {
      final ctx = _context(completed: {'i1'});
      expect(ctx.source, NavigationSource.groupRecitationCollection);
      expect(ctx.planTextItems, hasLength(1));
      expect(ctx.currentTextIndex, 0);
      expect(ctx.canSwipe, isFalse);
      final item = ctx.currentItem!;
      expect(item.isSourceReference, isTrue);
      expect(item.title, '84000: Monday');
      expect(item.textId, 't1');
      expect(item.sources.map((s) => s.textId), ['t1', 't2', 't3']);
      expect(item.subtaskIds, ['i1', 'i2', 'i3']);
      expect(item.completedSubtaskIds, {'i1'});
      expect(ctx.language, 'en');
    });

    test('carries the event, group and collection for an attendee', () {
      final ctx = _context();
      expect(ctx.eventId, 'e1');
      expect(ctx.isLiveRecitation, isTrue);
      expect(ctx.collectionId, 'c1');
      expect(ctx.groupId, 'g1');
      expect(ctx.groupTitle, 'Sangha');
    });

    test('an online attendee leaves live following to the stream', () {
      final ctx = _context(online: true);
      expect(ctx.isOnlineAttendee, isTrue);
      expect(ctx.isLiveRecitation, isFalse);
    });

    test('keeps the live segment only when the first text is live', () {
      expect(
        _context(liveTextId: 't1', liveSegmentId: 's9').targetSegmentId,
        's9',
      );
      expect(
        _context(liveTextId: 't2', liveSegmentId: 's9').targetSegmentId,
        isNull,
      );
    });

    test('each chant of a mixed collection loads in its own language', () {
      final mixed = GroupRecitationCollection(
        id: 'c1',
        groupId: 'g1',
        name: 'Mixed',
        items: [
          _chant('i1', 't1', 1).copyLanguage('bo'),
          _chant('i2', 't2', 2),
        ],
      );
      final ctx = groupEventCollectionNavigationContext(
        eventId: 'e1',
        key: _key,
        collection: mixed,
        completionState: const GroupRecitationCollectionCompletionState(),
        isOnlineAttendee: false,
      );
      expect(ctx.language, 'bo');
      final params = [
        for (final source in ctx.currentItem!.sources)
          ReaderParams(
            textId: source.textId,
            navigationContext: ctx,
            sourceLanguage: source.language,
          ),
      ];
      expect(params.map((p) => p.language), ['bo', 'en']);
      // Without its own language, a text keeps the navigation's.
      expect(ReaderParams(textId: 't2', navigationContext: ctx).language, 'bo');
    });

    test('read-only records nothing', () {
      final ctx = _context(readOnly: true, completed: {'i1'});
      expect(ctx.collectionId, isNull);
      expect(ctx.currentItem!.completedSubtaskIds, isEmpty);
    });
  });

  group('GroupRecitationCompletionService on a stacked collection', () {
    late _FakeRepository repository;
    late _RecordingAnalytics analytics;
    late ProviderContainer container;

    setUp(() {
      repository = _FakeRepository();
      analytics = _RecordingAnalytics();
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _SignedInAuth()),
          groupProfileRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);
      // Kept alive as the event page does while its reader is open.
      final sub = container.listen(
        groupRecitationCollectionCompletionProvider(_key),
        (_, _) {},
      );
      addTearDown(sub.close);
    });

    test('Finish completes every chant not yet done', () async {
      await container
          .read(groupRecitationCompletionProvider)
          .completeCurrent(_context(completed: {'i1'}));
      expect(repository.completedCalls, unorderedEquals(['i2', 'i3']));
      final state = container.read(
        groupRecitationCollectionCompletionProvider(_key),
      );
      expect(state.isCompleted('i2'), isTrue);
      expect(state.isCompleted('i3'), isTrue);
    });

    test('finishing the last chants reports the collection once', () async {
      // The server answers every chant at the same moment.
      repository.gate = Completer<void>();
      final finish = container
          .read(groupRecitationCompletionProvider)
          .completeCurrent(_context());
      await Future<void>.delayed(Duration.zero);
      repository.gate!.complete();
      await finish;
      expect(repository.completedCalls, unorderedEquals(['i1', 'i2', 'i3']));
      expect(
        analytics.events.where(
          (e) => e == AnalyticsEvents.recitationCollectionItemCompleted,
        ),
        hasLength(3),
      );
      expect(
        analytics.events.where(
          (e) => e == AnalyticsEvents.recitationCollectionCompleted,
        ),
        hasLength(1),
      );
    });

    test('read-only completes nothing', () async {
      await container
          .read(groupRecitationCompletionProvider)
          .completeCurrent(_context(readOnly: true));
      expect(repository.completedCalls, isEmpty);
    });
  });
}
